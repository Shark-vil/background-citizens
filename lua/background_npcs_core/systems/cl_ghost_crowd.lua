--[[
	Ghost crowd (EXPERIMENTAL, "bgn_cl_ghost_crowd"): cheap client-side figures far away, in a ring past the
	real actors, so the city looks fuller than the server could afford.

	- Ghosts are ClientsideModels with the looks (model, skin, bodygroups) of real actors you have seen.
	- They copy the mood of the real actors around you: calm (walk, sometimes stand) or panic (run away).
	  Panic wins from PANIC_SHARE of the actors in the "danger" state group, one scared actor matters more
	  than a dozen walkers.
	- They walk from point to point (server navigation, sv_ghost_crowd.lua) and never towards the player.
	- When the player comes close they leave: removed at once when out of sight, otherwise they run away
	  and fade out only as a last resort. The real actors that spawn there take their place.
--]]

local cvar_enable = GetConVar('bgn_cl_ghost_crowd')
local cvar_max = GetConVar('bgn_cl_ghost_crowd_max')

local THINK_PERIOD = 0.25
local MOOD_PERIOD = 1
local POINTS_PERIOD = 3
local STEP_DIST = 700        -- farthest next point
local MAX_STEP_Z = 72        -- the most height change between two points
local FADE_TIME = 1.5
local PANIC_SHARE = 0.2
local MAX_LOOKS = 32
local SPAWN_PER_THINK = 2
local HEAD = Vector(0, 0, 64)
local CHEST = Vector(0, 0, 40)
local VIEW_DOT = 0.4         -- a bit wider than a usual horizontal FOV
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
local mood = { panic = false, idle = 0.25 }
local looks, looks_index = {}, {}

-- Inner radius: ghosts leave inside it. Outer: they live up to it.
local function Radii()
	local radius = GetConVar('bgn_spawn_radius'):GetFloat()
	return radius * 0.5, radius * 1.5
end

local function IsSeen(eye, eye_dir, pos)
	local dir = pos - eye
	dir:Normalize()
	if eye_dir:Dot(dir) < VIEW_DOT then return false end
	return not util.TraceLine({ start = eye, endpos = pos, mask = MASK_VISIBLE }).Hit
end

-- ---------------------------------------------------------------------------
-- Looks and mood, taken from the real actors around
-- ---------------------------------------------------------------------------

local function BodygroupsOf(ent)
	local chars = {}
	for i = 0, ent:GetNumBodyGroups() - 1 do
		local value = ent:GetBodygroup(i)
		chars[#chars + 1] = value < 10 and tostring(value) or string.char(87 + value) -- SetBodyGroups: 0-9, a-z
	end
	return table.concat(chars)
end

local function RememberLook(npc)
	local look = { model = npc:GetModel(), skin = npc:GetSkin(), bodygroups = BodygroupsOf(npc) }
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

local function UpdateMood()
	local actors = bgNPC.Actors.GetAll()
	local total, danger, idle = 0, 0, 0

	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:IsAlive() and actor:GetNPC()
		if IsValid(npc) and not npc:IsDormant() then
			local state = actor:GetState()
			total = total + 1
			if bgNPC.States.GetGroup(state) == 'danger' then danger = danger + 1 end
			if state == 'idle' then idle = idle + 1 end
			if not actor:InVehicle() then RememberLook(npc) end
		end
	end

	local was_panic = mood.panic
	mood.panic = total > 0 and danger / total >= PANIC_SHARE
	mood.idle = total > 0 and math.min(idle / total, 0.6) or 0.25

	-- A fresh panic spreads at once: walking ghosts drop their goal and run
	if mood.panic and not was_panic then
		for i = 1, #ghosts do ghosts[i].target = nil; ghosts[i].idle_until = nil end
	end
end

-- ---------------------------------------------------------------------------
-- Ghosts
-- ---------------------------------------------------------------------------

local function RemoveGhost(i)
	local ghost = ghosts[i]
	if IsValid(ghost.ent) then ghost.ent:Remove() end
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

local function CreateGhost(pos)
	local look = looks[math.random(#looks)] or { model = FALLBACK_MODELS[math.random(#FALLBACK_MODELS)], skin = 0, bodygroups = '' }
	local ent = ClientsideModel(look.model)
	if not IsValid(ent) then return end

	-- Vehicles, helicopters and other actors without a walk animation can't be ghosts
	if ent:SelectWeightedSequence(ACT_WALK) < 0 then
		ent:Remove()
		ForgetLook(look)
		return
	end

	ent:SetSkin(look.skin)
	ent:SetBodyGroups(look.bodygroups)
	ent:SetPos(pos)
	ent:SetAngles(Angle(0, math.random(0, 359), 0))
	ent.bgn_ghost_alpha = 0
	ent.RenderOverride = DrawGhost

	local ghost = { ent = ent, pos = Vector(pos), alpha = 0, cycle = math.random(), yaw = ent:GetAngles().y }
	SetActivity(ghost, ACT_IDLE)
	ghosts[#ghosts + 1] = ghost
end

-- Next point: within STEP_DIST, not back, not towards the player (strictly away in panic), outside the inner radius.
local function NextPoint(ghost, ply_pos, r_in, run_away)
	local from = ghost.pos
	local away = from - ply_pos
	away.z = 0
	away:Normalize()
	local min_dot = run_away and 0.3 or -0.2
	local r_in_sqr = r_in * r_in
	local candidates = {}

	graph:ForEachInRadius(from, STEP_DIST, function(_, pos, dist_sqr)
		if dist_sqr < 2500 or math.abs(pos.z - from.z) > MAX_STEP_Z or pos == ghost.prev then return end
		if pos:DistToSqr(ply_pos) < r_in_sqr then return end
		local dir = pos - from
		dir.z = 0
		dir:Normalize()
		local dot = dir:Dot(away)
		if dot >= min_dot then
			candidates[#candidates + 1] = { pos = pos, score = math.random() + (run_away and dot or 0) }
		end
	end)

	table.sort(candidates, function(a, b) return a.score > b.score end)

	for i = 1, math.min(#candidates, 3) do
		local pos = candidates[i].pos
		if not util.TraceLine({ start = from + CHEST, endpos = pos + CHEST, mask = MASK_SOLID_BRUSHONLY }).Hit then
			return pos
		end
	end
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

	if dist > r_out * 1.15 then return Leave(ghost, seen) end

	if dist < r_in then
		if not seen or dist < r_in * 0.6 then return Leave(ghost, seen) end
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

local function TrySpawn(ply_pos, eye, eye_dir, r_in, r_out)
	for _ = 1, 4 do
		local id = graph:GetRandom()
		local pos = id and graph:GetPos(id)
		if not pos then return end

		local dist = pos:Distance(ply_pos)
		if dist >= r_in * 1.2 and dist <= r_out and (dist > r_out * 0.85 or not IsSeen(eye, eye_dir, pos + HEAD)) then
			CreateGhost(pos)
			return
		end
	end
end

bgNPC.Test.Add('ghost_crowd_next_point', function(check)
	local saved = graph
	graph = bgNPC.NodeGraph(256)
	local ply_pos = Vector(-1000, 0, 0)
	local ghost = { pos = Vector(0, 0, 0) }

	-- Only points towards the player: nothing to pick
	graph:AddNode(Vector(-300, 0, 0))
	graph:AddNode(Vector(-300, 100, 0))
	check(NextPoint(ghost, ply_pos, 200, false) == nil, 'never walks towards the player')

	-- A point too high and one inside the inner radius are skipped too
	graph:AddNode(Vector(300, 0, 500))
	check(NextPoint(ghost, ply_pos, 1250, false) == nil, 'skips high and inner radius points')

	graph:AddNode(Vector(300, 0, 0))
	local pos = NextPoint(ghost, ply_pos, 200, true)
	check(pos == nil or pos == Vector(300, 0, 0), 'runs away from the player') -- nil: a wall in the way on this map

	graph = saved
end)

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

		if not cvar_enable:GetBool() or not GetConVar('bgn_enable'):GetBool() or not IsValid(ply) then
			RemoveAll()
			graph = nil
			points_center = nil
			wait(1)
			continue
		end

		local now = CurTime()
		local ply_pos = ply:GetPos()
		local eye, eye_dir = ply:EyePos(), ply:EyeAngles():Forward()
		local r_in, r_out = Radii()

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
			for _ = 1, SPAWN_PER_THINK do
				if #ghosts >= max then break end
				TrySpawn(ply_pos, eye, eye_dir, r_in, r_out)
			end
			while #ghosts > max do RemoveGhost(#ghosts) end
		end

		wait(THINK_PERIOD)
	end
end)

-- shortcut: every ghost animates every frame, add an update LOD by distance if 100+ ghosts cost too much FPS
hook.Add('Think', 'BGN_GhostCrowd', function()
	if #ghosts == 0 then return end
	local dt = FrameTime()

	for i = #ghosts, 1, -1 do
		local ghost = ghosts[i]
		local ent = ghost.ent

		if not IsValid(ent) then
			table.remove(ghosts, i)
			continue
		end

		ghost.alpha = math.Approach(ghost.alpha, ghost.fading and 0 or 1, dt / FADE_TIME)
		if ghost.fading and ghost.alpha == 0 then
			RemoveGhost(i)
			continue
		end
		ent.bgn_ghost_alpha = ghost.alpha

		local target = ghost.target
		if target and ghost.speed > 0 then
			local to = target - ghost.pos
			local dist = to:Length()
			local step = ghost.speed * dt
			if dist <= step then
				ghost.pos = target
				ghost.target = nil
			else
				ghost.pos = ghost.pos + to * (step / dist)
			end
			ent:SetPos(ghost.pos)
		end

		if ghost.target_yaw then
			ghost.yaw = math.ApproachAngle(ghost.yaw, ghost.target_yaw, 360 * dt)
			ent:SetAngles(Angle(0, ghost.yaw, 0))
		end

		ghost.cycle = (ghost.cycle + dt / ghost.seq_len) % 1
		ent:SetCycle(ghost.cycle)
	end
end)
