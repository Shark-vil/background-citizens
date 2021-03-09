local movement_map = {}
local movement_ignore = {}
local dist_limit
local reset_ignore_time = 15

local function UpdateDistLimit()
	dist_limit = 250000
	if navmesh.IsLoaded() then
		dist_limit = GetConVar('bgn_ptp_distance_limit'):GetFloat() ^ 2
	end
end

UpdateDistLimit()

hook.Add('PostCleanupMap', 'BGN_CleanupNPCsMovementMaps', function()
	movement_map = {}
	movement_ignore = {}
	UpdateDistLimit()
end)

local function IsIgnorePosition(npc, pos)
	if movement_ignore[npc] ~= nil then
		for _, data in ipairs(movement_ignore[npc]) do
			if data.pos == pos and data.resetTime > CurTime() then
				return true
			end
		end
	end
	return false
end

local function getPositionsInRadius(npc)
	local npc_pos = npc:GetPos()
	local radius_positions = {}

	for _, v in ipairs(bgNPC.points) do
		if v.pos:DistToSqr(npc_pos) <= dist_limit then
			if IsIgnorePosition(npc, v.pos) then
				goto skip
			end

			table.insert(radius_positions, v)
		end

		::skip::
	end

	return radius_positions
end

local function updateMovement(npc)
	local positions = getPositionsInRadius(npc)
	if #positions == 0 then return nil end

	local v, key = table.Random(positions)

	movement_map[npc] = {
		pos = v.pos,
		index = key,
		resetTime = CurTime() + reset_ignore_time,
		start_pos = npc:GetPos(),
		start_time = CurTime()
	}

	return movement_map[npc]
end

local function nextMovement(npc)
	if movement_map[npc] ~= nil then
		local map = movement_map[npc]
		local parents = bgNPC.points[map.index].parents

		if #parents == 0 then return nil end

		local npc_pos = npc:GetPos()
		for _, index in ipairs(parents) do
			local pos = bgNPC.points[index].pos

			if IsIgnorePosition(npc, pos) then
				goto skip
			end

			if pos:DistToSqr(npc_pos) <= dist_limit and bgNPC:NPCIsViewVector(npc, pos) then
				local other_entities = ents.FindInSphere(pos, 100)
				local other_npc_count = 0
				for _, ent in ipairs(other_entities) do
					if ent:IsVehicle() or ent:GetClass():StartWith('prop_') then
						goto skip
					end

					if ent:IsNPC() and ent ~= npc then
						other_npc_count = other_npc_count + 1
					end

					if other_npc_count > 3 then
						goto skip
					end
				end

				movement_map[npc] = {
					pos = pos,
					index = index,
					resetTime = CurTime() + reset_ignore_time,
					start_pos = npc:GetPos(),
					start_time = CurTime()
				}

				return movement_map[npc]
			end

			::skip::
		end
	end

	return nil
end

hook.Add('BGN_PostOpenDoor', 'BGN_ReloadNPCStateAfterDoorOpen', function(actor)
	if actor:GetState() ~= 'walk' then return end

	local npc = actor:GetNPC()
	local map = movement_map[npc]
	if map ~= nil then
		map.resetTime = 0
	end
end)

hook.Add("BGN_SetNPCState", "BGN_ResetIgnorePointsAfterStateChange", function(actor, state)
	if state == 'walk' then return end

	local npc = actor:GetNPC()
	movement_map[npc] = nil
	movement_ignore[npc] = nil
end)

timer.Create('BGN_Timer_StollController', 0.5, 0, function()
	if #bgNPC.points == 0 then return end
	
	for _, actor in ipairs(bgNPC:GetAllByState('walk')) do
		if not actor:IsAlive() or actor:IsAnimationPlayed() then goto skip end

		local npc = actor:GetNPC()
		local map = movement_map[npc]
		local data = actor:GetStateData()
		data.schedule = data.schedule or 'walk'

		if map == nil then
			map = updateMovement(npc)

			if map == nil then
				goto skip
			end
			
			actor:WalkToPos(map.pos, data.schedule)
			
			movement_ignore[npc] = movement_ignore[npc] or {}
			table.insert(movement_ignore[npc], {
				pos = map.pos,
				resetTime = CurTime() + reset_ignore_time
			})
		else
			local getNewPos = false

			if map.start_time + 5 < CurTime() and npc:GetPos():DistToSqr(map.start_pos) <= 2500 then
				getNewPos = true
			elseif map.resetTime < CurTime() or npc:GetPos():DistToSqr(map.pos) <= 2500 then -- 50 ^ 2
				getNewPos = true
			end

			if not getNewPos then
				goto skip
			end

			if math.random(0, 100) <= 10 then
				actor:SetState('idle')
				return
			end

			map = nextMovement(npc)
			if map == nil then
				map = updateMovement(npc)
				if map == nil then
					bgNPC:Log('Can\'t find the next move point! Reset tables...', 'Walking')
					movement_map[npc] = nil
					movement_ignore[npc] = nil
					goto skip
				end
			end

			actor:WalkToPos(map.pos, data.schedule)

			movement_ignore[npc] = movement_ignore[npc] or {}
			table.insert(movement_ignore[npc], {
				pos = map.pos,
				resetTime = CurTime() + reset_ignore_time
			})
		end

		::skip::
	end
end)

timer.Create('BGN_StollRandomSwitchMovementType', 1, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('walk')) do
		if actor:IsAlive() then
			local data = actor:GetStateData()
			if data.schedule == 'run' then
				if data.runReset < CurTime() then
					actor:UpdateStateData({ 
						schedule = 'walk',
						runReset = 0
					})
				end
			elseif math.random(0, 100) == 0 then
				actor:UpdateStateData({ 
					schedule = 'run',
					runReset = CurTime() + 20
				})
			end
		end
	end

	for npc, tbl in pairs(movement_ignore) do
		for i = #tbl, 1, -1 do
			if tbl[i].resetTime < CurTime() then
				table.remove(tbl, i)
			end
		end
	end
end)