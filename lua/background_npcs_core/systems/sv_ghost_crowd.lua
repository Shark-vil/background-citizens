--[[
	Ghost crowd (EXPERIMENTAL), server side (rules: sh_ghost_crowd.lua).
	- Local mode: sends navigation points around a player to its client side crowd (cl_ghost_crowd.lua).
	- Server mode ("bgn_ghost_crowd"): runs the ghosts itself for every player, so all players see the same
	  crowd. A ghost seen by a player who comes inside the inner radius turns into a real actor of the same type
	  and look on its spot (handoff); unseen ghosts there just go, the regular spawner fills that area.

	Navigation answers are cached per map cell and radius, so players standing near each other (or one player
	walking back and forth) and the server ghosts share one navigation query.
--]]

local REQUEST_PERIOD = 2
local MAX_RADIUS = 10000
local MAX_POINTS = 1500
local CELL = 1024
local CACHE_TIME = 15

local cache = {}

local function CellKey(pos, radius)
	return math.floor(pos.x / CELL) .. ':' .. math.floor(pos.y / CELL) .. ':' .. math.floor(pos.z / CELL) .. ':' .. radius
end

local function GetPoints(pos, radius)
	local key = CellKey(pos, radius)
	local entry = cache[key]
	if entry and entry.time > CurTime() then return entry.points end

	-- The cell center, so every player of the cell gets the same points
	local center = Vector((math.floor(pos.x / CELL) + 0.5) * CELL, (math.floor(pos.y / CELL) + 0.5) * CELL, pos.z)
	local points = bgNPC.Nav.GetPointsInRadius(center, radius, 'walk', MAX_POINTS)

	while #points > MAX_POINTS do
		local i = math.random(#points)
		points[i] = points[#points]
		points[#points] = nil
	end

	cache[key] = { time = CurTime() + CACHE_TIME, points = points }
	return points
end

timer.Create('BGN_GhostCrowdCacheCleanup', CACHE_TIME, 0, function()
	local now = CurTime()
	for key, entry in pairs(cache) do
		if entry.time <= now then cache[key] = nil end
	end
end)

hook.Add('BGN_NavProviderChanged', 'BGN_GhostCrowdCache', function() cache = {} end)

bgNPC.Net.Receive('bgn_ghost_crowd_points', function(ply, radius)
	if not isnumber(radius) or (ply.bgn_ghost_points_next or 0) > CurTime() then return end
	ply.bgn_ghost_points_next = CurTime() + REQUEST_PERIOD

	-- Centered on the player's real position, the client only picks the radius (rounded: fewer cache keys)
	radius = math.Round(math.Clamp(radius, 0, MAX_RADIUS), -2)
	bgNPC.Net.Send('bgn_ghost_crowd_points', ply, GetPoints(ply:GetPos(), radius))
end)

-- ---------------------------------------------------------------------------
-- Server mode
-- ---------------------------------------------------------------------------

local GhostCrowd = bgNPC.GhostCrowd
local THINK_PERIOD = 0.25
local MOOD_PERIOD = 1
local SPAWN_PER_THINK = 2
local SPAWN_TRIES = 8
local MAX_LOOKS = 32
local PANIC_SHARE = 0.2
local PANIC_HOLD = 10
local SYNC_PERIOD = 2
local GROUND_UP = Vector(0, 0, 48)
local GROUND_DOWN = Vector(0, 0, 160)

local ghosts = {} -- id -> { id, look, seg, seg_end, prev, fleeing, fade_at }
local next_id = 0
local looks, looks_index = {}, {}
local moods = {} -- player -> { panic_until, idle }
local outbox = {}
local next_mood = 0

-- Every change goes to all clients in one message per think. Ops: a segment (with the look when the ghost is
-- new), { fade = true }, { remove = true }, { ent = entity index } (handoff).
local function Queue(op)
	outbox[#outbox + 1] = op
end

local function Flush()
	if #outbox == 0 then return end
	bgNPC.Net.Send('bgn_ghost_crowd', nil, outbox)
	outbox = {}
end

local function SegmentOp(ghost, with_look)
	local seg = ghost.seg
	return { id = ghost.id, from = seg.from, to = seg.to, t0 = seg.t0, speed = seg.speed, run = seg.run,
		look = with_look and ghost.look or nil, fade = ghost.fade_at ~= nil or nil }
end

-- @param to Vector|nil nil stands still for duration seconds
local function SetSegment(ghost, from, to, run, now, duration)
	local speed = to and (run and GhostCrowd.RUN_SPEED or GhostCrowd.WALK_SPEED) or 0
	ghost.seg = { from = from, to = to or from, t0 = now, speed = speed, run = run or nil }
	ghost.seg_end = now + (to and from:Distance(to) / speed or duration)
	Queue(SegmentOp(ghost, false))
end

local function Remove(ghost)
	ghosts[ghost.id] = nil
	Queue({ id = ghost.id, remove = true })
end

local function Leave(ghost, seen, now)
	if not seen then return Remove(ghost) end -- nobody looks, gone at once
	ghost.fade_at = now + GhostCrowd.FADE_TIME
	Queue({ id = ghost.id, fade = true })
end

local function RemoveAll()
	for _, ghost in pairs(ghosts) do Remove(ghost) end
	Flush()
end

-- ---------------------------------------------------------------------------
-- Looks and mood, taken from the real actors
-- ---------------------------------------------------------------------------

local function RememberLook(actor, npc)
	local look = { type = actor:GetType(), model = npc:GetModel(), skin = npc:GetSkin(),
		bodygroups = GhostCrowd.BodygroupsOf(npc) }
	local key = look.type .. look.model .. look.skin .. look.bodygroups
	if looks_index[key] then return end

	if #looks >= MAX_LOOKS then
		local old = table.remove(looks, 1)
		looks_index[old.type .. old.model .. old.skin .. old.bodygroups] = nil
	end
	looks[#looks + 1] = look
	looks_index[key] = true
end

-- Panic around a player: PANIC_SHARE of the actors within the ghosts' ring in danger, or someone wanted there
local function UpdateMoods(players, r_out)
	local now = CurTime()
	local r_out_sqr = r_out * r_out
	local wanted = bgNPC.Modules.Get('wanted')
	local wanted_list = wanted and wanted:GetAllWanted() or {}
	local actors = bgNPC.Actors.GetAll()

	for _, actor in ipairs(actors) do
		local npc = actor:IsAlive() and not actor:InVehicle() and actor:GetNPC()
		if IsValid(npc) and not actor.data.hidden and (npc:SelectWeightedSequence(ACT_WALK) or -1) >= 0
			and (npc:SelectWeightedSequence(ACT_IDLE) or -1) >= 0
		then
			RememberLook(actor, npc)
		end
	end

	for _, p in ipairs(players) do
		local mood = moods[p.ply] or { panic_until = 0, idle = 0.25 }
		moods[p.ply] = mood

		local total, danger, idle = 0, 0, 0
		for _, actor in ipairs(actors) do
			local npc = actor:IsAlive() and actor:GetNPC()
			if IsValid(npc) and npc:GetPos():DistToSqr(p.pos) <= r_out_sqr then
				local state = actor:GetState()
				total = total + 1
				if actor:EqualStateGroup('danger') or actor:EqualStateGroup('assault') or state == 'retreat' then
					danger = danger + 1
				end
				if state == 'idle' then idle = idle + 1 end
			end
		end

		local wanted_near = false
		for _, w in ipairs(wanted_list) do
			if IsValid(w.target) and w.target:GetPos():DistToSqr(p.pos) <= r_out_sqr then wanted_near = true break end
		end

		local was_panic = mood.panic_until > now
		if (total > 0 and danger / total >= PANIC_SHARE) or wanted_near then mood.panic_until = now + PANIC_HOLD end
		mood.idle = total > 0 and math.min(idle / total, 0.6) or 0.25

		-- A fresh panic spreads at once: the ghosts around drop their goal and run
		if not was_panic and mood.panic_until > now then
			for _, ghost in pairs(ghosts) do
				if ghost.seg.from:DistToSqr(p.pos) <= r_out_sqr then ghost.seg_end = 0 end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Decisions
-- ---------------------------------------------------------------------------

local function GroundPos(pos)
	local tr = util.TraceLine({ start = pos + GROUND_UP, endpos = pos - GROUND_DOWN, mask = MASK_NPCSOLID_BRUSHONLY })
	return tr.Hit and not tr.StartSolid and tr.HitPos or pos
end

-- A real actor of the ghost's type and look on its spot, facing its way. Clients drop the ghost when they get the entity.
-- Over the type limit too: the remover then takes over-limit actors nobody sees (sv_actor_remover.lua), which beats
-- a figure vanishing in front of the player. Not on an overloaded server (core/sv_server_load.lua).
-- @return boolean
local function Handoff(ghost, pos)
	local look = ghost.look
	local limit = bgNPC.Config.GetTypeLimit(look.type)
	if not bgNPC.Config.IsTypeActive(look.type) or limit == 0 then return false end
	if #bgNPC.Actors.GetNPCsByType(look.type) >= limit and bgNPC.ServerLoad.IsOverloaded() then return false end

	local actor = bgNPC:SpawnActor(look.type, GroundPos(pos))
	local npc = actor and actor:GetNPC()
	if not IsValid(npc) then return false end

	npc:SetModel(look.model)
	npc:SetSkin(look.skin)
	npc:SetBodyGroups(look.bodygroups)
	if ghost.seg.speed > 0 then npc:SetAngles(Angle(0, (ghost.seg.to - ghost.seg.from):Angle().y, 0)) end

	ghosts[ghost.id] = nil
	Queue({ id = ghost.id, ent = npc:EntIndex() })
	return true
end

-- Nav points near pos, from the cached cell answers
local function PointsNear(pos)
	local points = GetPoints(pos, math.Round(GhostCrowd.STEP_DIST + CELL, -2))
	return function(callback)
		for i = 1, #points do callback(points[i]) end
	end
end

local function Decide(ghost, now, players, r_in, r_out)
	if ghost.fade_at then
		if now >= ghost.fade_at then ghosts[ghost.id] = nil end
		return
	end

	local pos = GhostCrowd.SegmentPos(ghost.seg, now)
	local nearest, nearest_dist, seen = nil, math.huge, false
	for _, p in ipairs(players) do
		local dist = pos:Distance(p.pos)
		if dist < nearest_dist then nearest, nearest_dist = p, dist end
		if not seen and dist <= r_out * 1.2 then seen = GhostCrowd.IsSeen(p.eye, p.dir, pos + GhostCrowd.HEAD) end
	end

	if nearest_dist > r_out * 1.15 then return Leave(ghost, seen, now) end

	if nearest_dist < r_in then
		if not seen then return Remove(ghost) end
		if not ghost.fleeing then
			if Handoff(ghost, pos) then return end
			ghost.fleeing = true -- no slot for a real actor: it runs away like a local ghost
			ghost.seg_end = 0
		end
	end

	if now < ghost.seg_end then return end

	local mood = moods[nearest.ply] or { panic_until = 0, idle = 0.25 }
	local run = mood.panic_until > now or ghost.fleeing
	if not run and math.random() < mood.idle * 0.5 then
		SetSegment(ghost, pos, nil, false, now, math.Rand(3, 8))
		return
	end

	local r_in_sqr = (ghost.fleeing and 0 or r_in) ^ 2
	local target = GhostCrowd.NextPoint(pos, ghost.prev, nearest.pos, run, PointsNear(pos), function(point)
		for _, p in ipairs(players) do
			if point:DistToSqr(p.pos) < r_in_sqr then return true end
		end
		return false
	end)
	if not target then return Leave(ghost, seen, now) end

	ghost.prev = pos
	SetSegment(ghost, pos, target, run, now)
end

-- A point in the ring of player p, out of every player's inner radius, out of sight or farther than the real
-- actors may appear in sight (the same rule as the spawner)
local function TrySpawn(p, players, r_in, r_out, now)
	if #looks == 0 then return end
	local points = GetPoints(p.pos, math.Round(r_out * 1.2, -2))
	if #points == 0 then return end

	local visible_from = GetConVar('bgn_spawn_radius_visibility'):GetFloat()
	local r_near_sqr = (r_in * 1.2) ^ 2

	for _ = 1, SPAWN_TRIES do
		local pos = points[math.random(#points)]
		local ok = pos:Distance(p.pos) <= r_out
		for _, q in ipairs(players) do
			if not ok then break end
			local dist_sqr = pos:DistToSqr(q.pos)
			ok = dist_sqr >= r_near_sqr
				and (dist_sqr > visible_from * visible_from or not GhostCrowd.IsSeen(q.eye, q.dir, pos + GhostCrowd.HEAD))
		end

		if ok then
			next_id = next_id + 1
			local ghost = { id = next_id, look = looks[math.random(#looks)] }
			ghosts[next_id] = ghost
			ghost.seg = { from = pos, to = pos, t0 = now, speed = 0 }
			ghost.seg_end = now -- picks a goal on the next think
			Queue(SegmentOp(ghost, true))
			return
		end
	end
end

bgNPC.Tasks.Add('bgn_ghost_crowd_server', function(yield, wait, budget)
	while true do
		if not GhostCrowd.IsServerMode() or not GetConVar('bgn_enable'):GetBool() or player.GetCount() == 0 then
			if next(ghosts) then RemoveAll() end
			wait(1)
			continue
		end

		local now = CurTime()
		local r_in, r_out = GhostCrowd.Radii()
		local players = {}
		for _, ply in ipairs(player.GetAll()) do
			if ply:Alive() then
				players[#players + 1] = { ply = ply, pos = ply:GetPos(), eye = ply:EyePos(), dir = ply:GetAimVector() }
			end
		end

		if #players ~= 0 then
			if now >= next_mood then
				next_mood = now + MOOD_PERIOD
				UpdateMoods(players, r_out)
			end

			for _, ghost in pairs(ghosts) do
				Decide(ghost, now, players, r_in, r_out)
				budget()
			end

			-- every player gets a fair share of the limit
			local max = GetConVar('bgn_ghost_crowd_max'):GetInt()
			local share = math.ceil(max / #players)
			for _, p in ipairs(players) do
				local total, near = 0, 0
				for _, ghost in pairs(ghosts) do
					total = total + 1
					if ghost.seg.from:Distance(p.pos) <= r_out then near = near + 1 end
				end
				for _ = 1, SPAWN_PER_THINK do
					if total >= max or near >= share then break end
					TrySpawn(p, players, r_in, r_out, now)
					total, near = total + 1, near + 1
				end
				budget()
			end
		end

		Flush()
		wait(THINK_PERIOD)
	end
end)

hook.Add('PlayerDisconnected', 'BGN_GhostCrowdMood', function(ply) moods[ply] = nil end)

-- A client that starts drawing (joined, switched it on) gets every ghost at once
bgNPC.Net.Receive('bgn_ghost_crowd_sync', function(ply)
	if (ply.bgn_ghost_sync_next or 0) > CurTime() then return end
	ply.bgn_ghost_sync_next = CurTime() + SYNC_PERIOD

	local ops = {}
	for _, ghost in pairs(ghosts) do ops[#ops + 1] = SegmentOp(ghost, true) end
	if #ops ~= 0 then bgNPC.Net.Send('bgn_ghost_crowd', ply, ops) end
end)
