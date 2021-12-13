local bgNPC = bgNPC
local timer = timer
local hook = hook
local player = player
local GetConVar = GetConVar
local IsValid = IsValid
local ipairs = ipairs
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

	local current_state = actor:GetState()
	local current_data = actor:GetStateData()

	actor:CallStateAction(nil, 'stop', current_state, current_data)
	actor.anim_action = nil
	actor:ResetSequence()

	npc:SetPos(pos)
	npc:PhysWake()

	actor:RandomState()

	hook.Run('BGN_RespawnActor', actor, pos)
end

timer.Create('BGN_Timer_NPCRemover', 1, 0, function()
	local actors = bgNPC:GetAll()
	local actors_count = #actors

	if actors_count == 0 then return end

	local WantedModule = bgNPC:GetModule('wanted')

	local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	local bgn_enable = GetConVar('bgn_enable'):GetBool()
	local bgn_actors_teleporter = GetConVar('bgn_actors_teleporter'):GetBool()
	local max_teleporter = GetConVar('bgn_actors_max_teleports'):GetInt()
	local current_teleport = 0
	local player_list = player.GetHumans()
	local player_count = #player_list

	for i = 1, actors_count do
		local actor = actors[i]

		if not actor or not actor:IsAlive() or actor.eternal or actor.debugger or actor:GetData().hidden then
			continue
		end

		local npc = actor:GetNPC()

		if not bgn_enable or player_count == 0 or not bgNPC:IsActiveNPCType(actor:GetType()) then
			if not hook.Run('BGN_PreRemoveNPC', npc) then
				actor:Remove()
			end
		else
			local isRemove = true
			local npc_pos = npc:GetPos()

			for player_index = 1, #player_list do
				local ply = player_list[player_index]
				if IsValid(ply) then
					local ply_pos = ply:GetPos()
					local dist = npc_pos:DistToSqr(ply_pos)
					if dist < bgn_spawn_radius or bgNPC:PlayerIsViewVector(ply, npc_pos) then
						isRemove = false
						break
					end
				end
			end

			if isRemove then
				if not bgn_actors_teleporter then
					if not hook.Run('BGN_PreRemoveNPC', npc) then
						actor:Remove()
					end
				else
					local data = actor:GetData()

					if data.wanted_level == nil then
						if max_teleporter == current_teleport then continue end
						current_teleport = current_teleport + 1

						local is_entered_vehicle = FindExistCarAndEnterThis(actor)
						if not is_entered_vehicle then
							bgNPC:FindSpawnLocation(actor.uid, nil, nil, function(nodePosition)
								TeleportActor(actor, npc, nodePosition)
							end)
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
							if max_teleporter == current_teleport then continue end
							current_teleport = current_teleport + 1

							local is_entered_vehicle = FindExistCarAndEnterThis(actor)
							if not is_entered_vehicle then
								bgNPC:FindSpawnLocation(actor.uid, desiredPosition, nil, function(nodePosition)
									TeleportActor(actor, npc, nodePosition)
								end)
							end
						end
					end
				end
			end
		end
	end
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