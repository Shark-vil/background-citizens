local bgNPC = bgNPC
local hook = hook
local player = player
local GetConVar = GetConVar
local IsValid = IsValid
local ipairs = ipairs
local StopAnimator = slib.Animator.Stop
--

hook.Add('BGN_OnKilledActor', 'BGN_ActorRemoveFromData', function(actor)
	actor:RemoveActor()
end)

hook.Add('EntityRemoved', 'BGN_ActorRemoveFromData', function(ent)
	if not ent.isBgnActor then return end
	bgNPC:RemoveNPC(ent)
end)

local function FindExistCarAndEnterThis(actor)
	if not bgNPC:EnterActorInExistVehicle(actor) then
		return bgNPC:SpawnVehicleWithActor(actor)
	end
	return true
end

local function TeleportActor(actor, npc, pos)
	if not actor or not IsValid(npc) then return end
	if not bgNPC:IsValidSpawnArea(actor:GetType(), pos) then return end

	local current_state = actor:GetState()
	local current_data = actor:GetStateData()

	StopAnimator(npc)
	actor:CallStateAction(nil, 'stop', current_state, current_data)
	actor.anim_action = nil
	actor:ResetSequence()

	npc:SetPos(pos)
	npc:PhysWake()

	actor:RandomState()

	hook.Run('BGN_RespawnActor', actor, pos)
end

async.Add('bgn_actors_remover_process', function(yield, wait)
	local fasted_teleport = GetConVar('bgn_fasted_teleport'):GetBool()

	wait(1)

	local actors = bgNPC:GetAll()
	local actors_count = #actors

	if actors_count == 0 then return end

	local WantedModule = bgNPC:GetModule('wanted')

	local bgn_enable = GetConVar('bgn_enable'):GetBool()
	local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	local bgn_spawn_block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
	local bgn_spawn_radius_visibility = GetConVar('bgn_spawn_radius_visibility'):GetFloat() ^ 2
	local bgn_actors_teleporter = GetConVar('bgn_actors_teleporter'):GetBool()
	local max_teleporter = GetConVar('bgn_actors_max_teleports'):GetInt()
	local current_teleport = 0
	local player_list = player.GetHumans()
	local player_count = #player_list

	for i = 1, actors_count do
		local actor = actors[i]

		if not fasted_teleport then
			yield()
		end

		if not actor or not actor:IsAlive() or actor.eternal or actor.debugger or actor:GetData().hidden then
			continue
		end

		local npc = actor:GetNPC()
		local npc_type = actor:GetType()

		if not bgn_enable or player_count == 0 or not bgNPC:IsActiveNPCType(npc_type) then
			if not hook.Run('BGN_PreRemoveNPC', npc) then
				actor:Remove()
			end
		else
			local max_limit = bgNPC:GetLimitActors(npc_type)
			if max_limit == 0 or #bgNPC:GetAllNPCsByType(npc_type) > max_limit then
				actor:Remove()
				continue
			end

			local isRemove = true
			local npc_pos = npc:GetPos()

			for player_index = 1, #player_list do
				local ply = player_list[player_index]
				if not IsValid(ply) then continue end

				local ply_pos = ply:GetPos()
				local dist = npc_pos:DistToSqr(ply_pos)

				if dist > bgn_spawn_radius then
					if ply:slibIsTraceEntity(npc, dist, true) then
						isRemove = false
					end
				else
					if dist <= bgn_spawn_block_radius or dist <= bgn_spawn_radius_visibility then
						isRemove = false
					elseif not actor.toRemove and slib.chance(90) then
						isRemove = false
					end

					if isRemove and ply:slibIsTraceEntity(npc, dist, true) then
						isRemove = false
					end
				end

				if not isRemove then break end
			end

			if not isRemove then continue end

			if actor.toRemove or (not bgn_actors_teleporter and isRemove) then
				if not hook.Run('BGN_PreRemoveNPC', npc) then
					actor:Remove()
				end
			elseif isRemove then
				local data = actor:GetData()

				if data.wanted_level == nil then
					if max_teleporter == current_teleport then break end
					current_teleport = current_teleport + 1

					local is_entered_vehicle = FindExistCarAndEnterThis(actor)
					if not is_entered_vehicle then
						bgNPC:FindSpawnLocation(actor.uid, nil, nil, nil, function(nodePosition)
							TeleportActor(actor, npc, nodePosition)
						end, npc)
					end
				else
					local desiredPosition
					local wanted_list = WantedModule:GetAllWanted()

					for k = 1, #wanted_list do
						local WantedComponent = wanted_list[k]
						local Target = WantedComponent.target

						if IsValid(Target) and WantedComponent.level >= data.wanted_level then
							desiredPosition = Target:GetPos()
							break
						end
					end

					if not desiredPosition then
						if not hook.Run('BGN_PreRemoveNPC', npc) then
							actor:Remove()
						end
					else
						if max_teleporter == current_teleport then break end
						current_teleport = current_teleport + 1

						local is_entered_vehicle = FindExistCarAndEnterThis(actor)
						if not is_entered_vehicle then
							bgNPC:FindSpawnLocation(actor.uid, desiredPosition, bgn_spawn_radius_visibility, nil, function(nodePosition)
								TeleportActor(actor, npc, nodePosition)
							end, npc)
						end
					end
				end
			end
		end
	end

	yield()
end)

hook.Add('BGN_ResetEnemiesForActor', 'BGN_ClearLevelOnlyNPCs', function(actor)
	if not actor:HasTeam('police') then return end
	if actor.eternal then return end

	local data = actor:GetData()
	if data.wanted_level ~= nil then
		local npc = actor:GetNPC()

		local asset = bgNPC:GetModule('wanted')
		local wanted_list = asset:GetAllWanted()
		local success = false

		for i = 1, #wanted_list do
			local WantedClass = wanted_list[i]
			local target = WantedClass.target
			if IsValid(target) and WantedClass.level >= data.wanted_level then
				success = true
				break
			end
		end

		if not success and not hook.Run('BGN_PreRemoveNPC', npc) then
			bgNPC:Log('Remove wanted npc (reset targets)', 'Wanted NPC')
			actor:Remove()
		end
	end
end)

hook.Add('BGN_WantedLevelDown', 'BGN_ClearCurrentlyLevelOnlyNPCs', function(ent, level)
	for _, actor in ipairs(bgNPC:GetAllByTeam('police')) do
		local wanted_level = actor:GetData().wanted_level

		if wanted_level ~= nil and level < wanted_level then
			actor:RemoveTarget(ent)
		end
	end
end)