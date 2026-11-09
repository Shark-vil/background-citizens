--[[
	Ghost crowd (EXPERIMENTAL, "bgn_cl_ghost_crowd"): cheap client-side figures far away, in a ring past the
	real actors, so the city looks fuller than the server could afford.

	Server mode ("bgn_ghost_crowd", sv_ghost_crowd.lua): the server runs the ghosts and this file only draws them
	(segments from the server, the same for every player); the client settings do nothing then.
	A ghost the server turned into a real actor stays until its entity arrives, so there is no gap.
	Everything below is the local mode, this player's own ghosts that change nothing in the game:

	- Ghosts are ClientsideModels with the looks (model, skin, bodygroups) of real actors you have seen.
	- They copy the mood of the real actors around you: calm (walk, sometimes stand) or panic (run away).
	  Panic wins from PANIC_SHARE of the actors in a panic state group (synced from the server, the client
	  has no state registry), one scared actor matters more than a dozen walkers. Someone wanted nearby
	  panics them too. A panic lasts PANIC_HOLD seconds after its last cause.
	- They walk from point to point (server navigation, sv_ghost_crowd.lua) and never towards the player.
	  Their feet follow the ground (a trace down a few times a second), points often hang above it.
	- They keep out of the inner radius around every player: real actors live there (multiplayer too).
	- They appear out of sight. At the limit, a ghost behind the player moves into view.
	- When the player comes close they leave: removed at once when out of sight, otherwise they run away
	  and fade out only as a last resort. The real actors that spawn there take their place.
--]]

local cvar_enable = GetConVar('bgn_cl_ghost_crowd')
local cvar_max = GetConVar('bgn_cl_ghost_crowd_max')
local GhostCrowd = bgNPC.GhostCrowd
local HEAD = GhostCrowd.HEAD
local VIEW_DOT = GhostCrowd.VIEW_DOT
local Radii = GhostCrowd.Radii
local IsSeen = GhostCrowd.IsSeen
local HANDOFF_WAIT = 2 -- the most a handed off ghost waits for its real actor

local THINK_PERIOD = 0.25
local MOOD_PERIOD = 1
local POINTS_PERIOD = 3
local PANIC_SHARE = 0.2
local PANIC_HOLD = 10
local PANIC_GROUPS = { danger = true, assault = true }
local MAX_LOOKS = 32
local SPAWN_PER_THINK = 2
local GROUND_PERIOD = 0.15
local GROUND_UP = Vector(0, 0, 48)
local GROUND_DOWN = Vector(0, 0, 160)
local SPAWN_TRIES = 8
local ACT_PANIC = ACT_RUN_PROTECTED or ACT_RUN

local FALLBACK_MODELS = {
	'models/humans/group01/male_02.mdl', 'models/humans/group01/male_04.mdl', 'models/humans/group01/male_07.mdl',
	'models/humans/group01/female_01.mdl', 'models/humans/group01/female_03.mdl', 'models/humans/group01/female_06.mdl',
}

-- Script reload: drop the old ghosts, their models would leak otherwise
for _, ghost in ipairs(bgNPC.ghost_crowd or {}) do
	if IsValid(ghost.ent) then ghost.ent:Remove() end
end

local ghosts = {}
bgNPC.ghost_crowd = ghosts
local graph            -- bgNPC.NodeGraph of the last received points
local points_center    -- player position of the last request
local next_points_request = 0
local next_mood = 0
local mood = { panic = false, idle = 0.25, panic_until = 0 }
local looks, looks_index = {}, {}

-- Other players' positions: real actors live around them, ghosts keep out (filled every think)
local others = {}

local function NearOtherPlayer(pos, r_in_sqr)
	for i = 1, #others do
		if pos:DistToSqr(others[i]) < r_in_sqr then return true end
	end
	return false
end

-- @return number ground height under pos, pos.z when there is no ground in reach
local function GroundZ(pos)
	local tr = util.TraceLine({ start = pos + GROUND_UP, endpos = pos - GROUND_DOWN, mask = MASK_PLAYERSOLID_BRUSHONLY })
	return tr.Hit and not tr.StartSolid and tr.HitPos.z or pos.z
end

-- ---------------------------------------------------------------------------
-- Looks and mood, taken from the real actors around
-- ---------------------------------------------------------------------------

local function RememberLook(npc)
	local look = { model = npc:GetModel(), skin = npc:GetSkin(), bodygroups = GhostCrowd.BodygroupsOf(npc) }
	if not look.model then return end
	local key = look.model .. look.skin .. look.bodygroups
	if looks_index[key] then return end

	if #looks >= MAX_LOOKS then
		local old = table.remove(looks, 1)
		looks_index[old.model .. old.skin .. old.bodygroups] = nil
	end
	looks[#looks + 1] = look
	looks_index[key] = true
end

local function ForgetLook(look)
	for i = 1, #looks do
		if looks[i] == look then
			table.remove(looks, i)
			looks_index[look.model .. look.skin .. look.bodygroups] = nil
			return
		end
	end
end

-- Someone wanted (by the police) within the ghosts' ring
local function WantedNearby()
	local wanted = bgNPC.Modules.Get('wanted')
	local ply = LocalPlayer()
	if not wanted or not IsValid(ply) then return false end

	local _, r_out = Radii()
	local r_out_sqr = r_out * r_out
	local list = wanted:GetAllWanted()
	for i = 1, #list do
		local target = list[i].target
		if IsValid(target) and target:GetPos():DistToSqr(ply:GetPos()) <= r_out_sqr then return true end
	end
	return false
end

local function UpdateMood()
	local actors = bgNPC.Actors.GetAll()
	local total, danger, idle = 0, 0, 0

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:IsAlive() and actor:GetNPC()
		if IsValid(npc) and not npc:IsDormant() then
			local state = actor:GetState()
			total = total + 1
			if PANIC_GROUPS[actor.state_group] or state == 'retreat' then danger = danger + 1 end
			if state == 'idle' then idle = idle + 1 end
			if not actor:InVehicle() then RememberLook(npc) end
		end
	end

	local now = CurTime()
	if (total > 0 and danger / total >= PANIC_SHARE) or WantedNearby() then mood.panic_until = now + PANIC_HOLD end

	local was_panic = mood.panic
	mood.panic = now < mood.panic_until
	mood.idle = total > 0 and math.min(idle / total, 0.6) or 0.25

	-- A fresh panic spreads at once: walking ghosts drop their goal and run
	if mood.panic and not was_panic then
		for i = 1, #ghosts do ghosts[i].target = nil; ghosts[i].idle_until = nil end
	end
end

-- ---------------------------------------------------------------------------
-- Ghosts
-- ---------------------------------------------------------------------------

local server_ghosts = {} -- server mode: server id -> ghost
local server_synced = false
local server_mode = false

local function RemoveGhost(i)
	local ghost = ghosts[i]
	if IsValid(ghost.ent) then ghost.ent:Remove() end
	if ghost.id then server_ghosts[ghost.id] = nil end
	table.remove(ghosts, i)
end

local function RemoveAll()
	for i = #ghosts, 1, -1 do RemoveGhost(i) end
end

local function DrawGhost(ent)
	local alpha = ent.bgn_ghost_alpha
	if alpha >= 1 then
		ent:DrawModel()
		return
	end
	render.SetBlend(alpha)
	ent:DrawModel()
	render.SetBlend(1)
end

local function SetActivity(ghost, act)
	if ghost.act == act then return end
	local ent = ghost.ent
	if not IsValid(ent) then return end
	local seq = ent:SelectWeightedSequence(act)
	if seq < 0 and act == ACT_PANIC then seq = ent:SelectWeightedSequence(ACT_RUN) end
	if seq < 0 then return end

	ghost.act = act
	ent:ResetSequence(seq)
	ghost.seq_len = math.max(ent:SequenceDuration(seq), 0.1)
	ghost.speed = 0
	if act ~= ACT_IDLE then
		local speed = ent:GetSequenceGroundSpeed(seq)
		ghost.speed = speed > 0 and speed or (act == ACT_WALK and 70 or 200)
	end
end

-- @param server_look table|nil the look the server picked, a random seen one otherwise
-- @return table|nil the ghost
local function CreateGhost(pos, server_look)
	local look = server_look or looks[math.random(#looks)]
		or { model = FALLBACK_MODELS[math.random(#FALLBACK_MODELS)], skin = 0, bodygroups = '' }
	local ent = ClientsideModel(look.model)
	if not IsValid(ent) then return end

	-- Vehicles, helicopters and other actors without a walk or idle animation can't be ghosts
	-- (without idle the ghost stood in its bind pose, and its Think broke on a nil sequence length)
	if ent:SelectWeightedSequence(ACT_WALK) < 0 or ent:SelectWeightedSequence(ACT_IDLE) < 0 then
		ent:Remove()
		if not server_look then ForgetLook(look) end
		return
	end

	ent:SetSkin(look.skin)
	ent:SetBodyGroups(look.bodygroups)
	pos = Vector(pos.x, pos.y, GroundZ(pos))
	ent:SetPos(pos)
	ent:SetAngles(Angle(0, math.random(0, 359), 0))
	ent.bgn_ghost_alpha = 0
	ent.RenderOverride = DrawGhost

	local ghost = { ent = ent, pos = pos, z = pos.z, next_ground = 0, alpha = 0, cycle = math.random(), yaw = ent:GetAngles().y }
	SetActivity(ghost, ACT_IDLE)
	ghosts[#ghosts + 1] = ghost
	return ghost
end

-- ---------------------------------------------------------------------------
-- Server mode: the server's ghosts (sv_ghost_crowd.lua)
-- ---------------------------------------------------------------------------

local function ApplyServerOp(op, now)
	local ghost = server_ghosts[op.id]
	if not ghost then
		if not op.look or op.remove or op.ent then return end -- a ghost this client never got
		ghost = CreateGhost(op.from, op.look)
		if not ghost then return end
		ghost.id = op.id
		server_ghosts[op.id] = ghost
	end

	if op.remove then
		for i = #ghosts, 1, -1 do
			if ghosts[i] == ghost then RemoveGhost(i) break end
		end
		return
	end
	if op.ent then
		ghost.handoff_ent = op.ent
		ghost.handoff_until = now + HANDOFF_WAIT
		return
	end
	if op.fade then ghost.fading = true end
	if not op.from then return end

	ghost.seg = { from = op.from, to = op.to, t0 = op.t0, speed = op.speed }
	if op.speed > 0 then
		SetActivity(ghost, op.run and ACT_PANIC or ACT_WALK)
		ghost.rate = op.speed / math.max(ghost.speed, 1) -- the animation keeps up with the server's speed
		ghost.target_yaw = (op.to - op.from):Angle().y
	else
		SetActivity(ghost, ACT_IDLE)
		ghost.rate = 1
	end
end

bgNPC.Net.Receive('bgn_ghost_crowd', function(_, ops)
	if not server_mode or not istable(ops) then return end
	local now = CurTime()
	for _, op in ipairs(ops) do
		if istable(op) and isnumber(op.id) then ApplyServerOp(op, now) end
	end
end)

-- Next point (GhostCrowd.NextPoint) on the points the server sent, out of every player's inner radius
local function NextPoint(ghost, ply_pos, r_in, run_away)
	local r_in_sqr = r_in * r_in
	return GhostCrowd.NextPoint(ghost.pos, ghost.prev, ply_pos, run_away, function(callback)
		graph:ForEachInRadius(ghost.pos, GhostCrowd.STEP_DIST, function(_, pos) callback(pos) end)
	end, function(pos)
		return pos:DistToSqr(ply_pos) < r_in_sqr or NearOtherPlayer(pos, r_in_sqr)
	end)
end

local function Leave(ghost, seen)
	if not seen then return true end -- nobody looks, gone at once
	ghost.fading = true
	return false
end

-- @return true when the ghost must be removed now
local function Decide(ghost, now, ply_pos, eye, eye_dir, r_in, r_out)
	if ghost.fading then return false end

	local dist = ghost.pos:Distance(ply_pos)
	local seen = IsSeen(eye, eye_dir, ghost.pos + HEAD)

	if dist > r_out * 1.15 or NearOtherPlayer(ghost.pos, r_in * r_in) then return Leave(ghost, seen) end

	if dist < r_in then
		if not seen then return true end -- a seen one runs away, it never fades next to the player
		if not ghost.fleeing then
			ghost.fleeing = true
			ghost.target = nil
			ghost.idle_until = nil
		end
	end

	if ghost.target or (ghost.idle_until and now < ghost.idle_until) then return false end
	ghost.idle_until = nil

	local run = mood.panic or ghost.fleeing
	if not run and math.random() < mood.idle * 0.5 then
		SetActivity(ghost, ACT_IDLE)
		ghost.idle_until = now + math.Rand(3, 8)
		return false
	end

	local target = NextPoint(ghost, ply_pos, ghost.fleeing and 0 or r_in, run)
	if not target then return Leave(ghost, seen) end

	ghost.prev = ghost.pos
	ghost.target = target
	ghost.target_yaw = (target - ghost.pos):Angle().y
	SetActivity(ghost, run and ACT_PANIC or ACT_WALK)
	return false
end

-- @return Vector|nil a spawn point, one in front of the player when possible
local function FindSpawnPoint(ply_pos, eye, eye_dir, r_in, r_out)
	local r_in_sqr = r_in * r_in
	local fallback

	for _ = 1, SPAWN_TRIES do
		local id = graph:GetRandom()
		local pos = id and graph:GetPos(id)
		if not pos then return end

		local dist = pos:Distance(ply_pos)
		-- Spawn only out of sight, regardless of distance.
		if dist >= r_in * 1.2 and dist <= r_out and not NearOtherPlayer(pos, r_in_sqr)
			and not IsSeen(eye, eye_dir, pos + HEAD)
		then
			local dir = pos - eye
			dir:Normalize()
			if eye_dir:Dot(dir) > VIEW_DOT then return pos, true end
			fallback = fallback or pos
		end
	end

	return fallback, false
end

-- A ghost nobody sees, behind the player: it is the first to move into view at the limit
local function FindBehindGhost(eye, eye_dir)
	for i = 1, #ghosts do
		local ghost = ghosts[i]
		local dir = ghost.pos - eye
		dir:Normalize()
		if not ghost.fading and eye_dir:Dot(dir) < -0.2 then return i end
	end
end

local function TrySpawn(ply_pos, eye, eye_dir, r_in, r_out, max)
	local pos, in_front = FindSpawnPoint(ply_pos, eye, eye_dir, r_in, r_out)
	if not pos then return end

	if #ghosts >= max then
		if not in_front then return end
		local behind = FindBehindGhost(eye, eye_dir)
		if not behind then return end
		RemoveGhost(behind)
	end

	CreateGhost(pos)
end

bgNPC.Net.Receive('bgn_ghost_crowd_points', function(_, points)
	if not istable(points) then return end
	local new_graph = bgNPC.NodeGraph(256)
	for i = 1, #points do
		if isvector(points[i]) then new_graph:AddNode(points[i]) end
	end
	graph = new_graph
end)

-- ---------------------------------------------------------------------------
-- Loops: decisions a few times a second, movement every frame
-- ---------------------------------------------------------------------------

bgNPC.Tasks.Add('bgn_ghost_crowd', function(yield, wait, budget)
	while true do
		local ply = LocalPlayer()

		local is_server_mode = GhostCrowd.IsServerMode()
		if is_server_mode ~= server_mode then
			server_mode = is_server_mode
			RemoveAll()
			server_synced = false
		end

		if (not server_mode and not cvar_enable:GetBool()) or not GetConVar('bgn_enable'):GetBool() or not IsValid(ply) then
			RemoveAll()
			graph = nil
			points_center = nil
			server_synced = false
			wait(1)
			continue
		end

		-- the server runs the ghosts: ask for all of them once, then the updates come by themselves
		if server_mode then
			if not server_synced then
				server_synced = true
				bgNPC.Net.SendToServer('bgn_ghost_crowd_sync')
			end
			wait(THINK_PERIOD)
			continue
		end

		local now = CurTime()
		local ply_pos = ply:GetPos()
		local eye, eye_dir = ply:EyePos(), ply:EyeAngles():Forward()
		local r_in, r_out = Radii()

		table.Empty(others)
		for _, other in ipairs(player.GetAll()) do
			if other ~= ply and other:Alive() then others[#others + 1] = other:GetPos() end
		end

		if now >= next_points_request and (not points_center or points_center:Distance(ply_pos) > r_in * 0.5) then
			next_points_request = now + POINTS_PERIOD
			points_center = ply_pos
			bgNPC.Net.SendToServer('bgn_ghost_crowd_points', r_out * 1.2)
		end

		if now >= next_mood then
			next_mood = now + MOOD_PERIOD
			UpdateMood()
		end

		if graph then
			for i = #ghosts, 1, -1 do
				if Decide(ghosts[i], now, ply_pos, eye, eye_dir, r_in, r_out) then RemoveGhost(i) end
				budget()
			end

			local max = cvar_max:GetInt()
			while #ghosts > max do RemoveGhost(#ghosts) end
			for _ = 1, SPAWN_PER_THINK do
				TrySpawn(ply_pos, eye, eye_dir, r_in, r_out, max)
			end
		end

		wait(THINK_PERIOD)
	end
end)

-- shortcut: every ghost animates every frame, add an update LOD by distance if 100+ ghosts cost too much FPS
hook.Add('Think', 'BGN_GhostCrowd', function()
	if #ghosts == 0 then return end
	local dt = FrameTime()
	local now = CurTime()

	for i = #ghosts, 1, -1 do
		local ghost = ghosts[i]
		local ent = ghost.ent

		if not IsValid(ent) then
			RemoveGhost(i)
			continue
		end

		ghost.alpha = math.Approach(ghost.alpha, ghost.fading and 0 or 1, dt / GhostCrowd.FADE_TIME)
		if ghost.fading and ghost.alpha == 0 then
			RemoveGhost(i)
			continue
		end
		ent.bgn_ghost_alpha = ghost.alpha

		if ghost.handoff_ent and (IsValid(Entity(ghost.handoff_ent)) or now > ghost.handoff_until) then
			RemoveGhost(i)
			continue
		end

		local target = ghost.target
		if ghost.seg then
			ghost.pos = GhostCrowd.SegmentPos(ghost.seg, now)
		elseif target and ghost.speed > 0 then
			local to = target - ghost.pos
			local dist = to:Length()
			local step = ghost.speed * dt
			if dist <= step then
				ghost.pos = target
				ghost.target = nil
			else
				ghost.pos = ghost.pos + to * (step / dist)
			end
		end

		-- the path runs between points that often hang above the ground: the feet follow a trace down
		if now >= ghost.next_ground then
			ghost.next_ground = now + GROUND_PERIOD
			ghost.ground = GroundZ(ghost.pos)
		end
		ghost.z = math.Approach(ghost.z, ghost.ground or ghost.pos.z, 300 * dt)
		ent:SetPos(Vector(ghost.pos.x, ghost.pos.y, ghost.z))

		if ghost.target_yaw then
			ghost.yaw = math.ApproachAngle(ghost.yaw, ghost.target_yaw, 360 * dt)
			ent:SetAngles(Angle(0, ghost.yaw, 0))
		end

		ghost.cycle = (ghost.cycle + dt * (ghost.rate or 1) / ghost.seq_len) % 1
		ent:SetCycle(ghost.cycle)
	end
end)
