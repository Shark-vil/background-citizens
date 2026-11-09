--
local fasted_teleport
local bgn_enable
local bgn_spawn_radius
local bgn_spawn_block_radius
local bgn_spawn_radius_visibility
local bgn_actors_teleporter
local max_teleporter
local current_teleport
local player_list
local player_count

hook.Add('BGN_OnKilledActor', 'BGN_ActorRemoveFromData', function(actor)
	actor:RemoveActor()
end)

hook.Add('EntityRemoved', 'BGN_ActorRemoveFromData', function(ent)
	if not ent.isBgnActor then return end
	bgNPC.Actors.Unregister(ent)
end)

local function FindExistCarAndEnterThis(actor)
	if not bgNPC:EnterActorInExistVehicle(actor) then
		return bgNPC:SpawnVehicleWithActor(actor)
	end
	return true
end

local function TeleportActor(actor, pos)
	if not actor or not bgNPC:IsValidSpawnArea(actor:GetType(), pos) then
		return
	end
	if not bgNPC:IsHiddenSpawnPosition(pos, actor:GetNPC()) then return end

	bgNPC:RespawnActor(actor, pos, function(success)
		if not success or not actor:IsAlive() then return end
		actor:RandomState()
		actor.__last_player_interaction = CurTime() + 5
	end)
end

-- states tied to other actors or to a spot: moved away, the others went on talking to empty air
local BUSY_STATES = {
	'dialogue', 'arrest', 'arrest_surrender', 'medic_revive', 'police_inspect_body', 'sit_to_chair', 'sit_to_chair_2',
	'scenic_npc',
}

local function SeenByAnyPlayer(npc)
	for i = 1, #player_list do
		if bgNPC.Util.CanSeeEntity(player_list[i], npc, true) then return true end
	end
	return false
end

local function IsValidRemovePositionAsync(actor, npc)
	local npc_pos = npc:GetPos()

	for player_index = 1, #player_list do
		local ply = player_list[player_index]
		if not IsValid(ply) then continue end

		local ply_pos = ply:GetPos()
		local dist = npc_pos:DistToSqr(ply_pos)

		if dist > bgn_spawn_radius then
			if bgNPC.Util.CanSeeEntity(ply, npc, true) then
				return false
			end
		else
			if dist <= bgn_spawn_block_radius then
				return false
			end

			if dist >= bgn_spawn_radius_visibility and (not actor.__last_player_interaction or actor.__last_player_interaction > CurTime()) then
				return false
			end

			if not actor.toRemove then
				return false
			end

			if bgNPC.Util.CanSeeEntity(ply, npc, true) then
				return false
			end
		end
	end

	return true
end

bgNPC.Tasks.Add('bgn_actors_last_player_interaction', function(yield, wait)
	while true do
		local players = player.GetHumans()
		local actors = bgNPC.Actors.GetAll()
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor:IsAlive() then
				local npc = actor:GetNPC()
				if not IsValid(npc) then continue end
				for k = 1, #players do
					local ply = players[k]
					if IsValid(ply) and bgNPC.Util.CanSeeEntity(ply, npc, true) then
						actor.__last_player_interaction = CurTime() + 10
						break
					end
					yield()
				end
			end
			yield()
		end
		yield()
	end
end)

local function run_remover_process_async(yield, wait, actors, actors_count)
	local WantedModule = bgNPC.Modules.Get('wanted')

	fasted_teleport = GetConVar('bgn_fasted_teleport'):GetBool()
	bgn_enable = GetConVar('bgn_enable'):GetBool()
	bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	bgn_spawn_block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
	bgn_spawn_radius_visibility = GetConVar('bgn_spawn_radius_visibility'):GetFloat() ^ 2
	bgn_actors_teleporter = GetConVar('bgn_actors_teleporter'):GetBool()
	max_teleporter = GetConVar('bgn_actors_max_teleports'):GetInt()
	current_teleport = 0
	player_list = player.GetHumans()
	player_count = #player_list
	local overloaded = bgNPC.ServerLoad.IsOverloaded()

	for i = 1, actors_count do
		yield()
		if not fasted_teleport then yield() end
		player_list = player.GetHumans()
		player_count = #player_list

		local actor = actors[i]

		if not actor or not actor:IsAlive() or actor.eternal or actor.debugger or actor.data.hidden then
			continue
		end

		local npc = actor:GetNPC()
		local npc_type = actor:GetType()

		if not bgn_enable or player_count == 0 or not bgNPC.Config.IsTypeActive(npc_type) then
			if not hook.Run('BGN_PreRemoveNPC', npc) then
				actor:Remove()
			end
		else
			if not actor.mechanics.ignore_limit then
				-- over the limit (a ghost handoff, a lowered limit): only actors no player sees, the rest wait their turn;
				-- an overloaded server (core/sv_server_load.lua) drops them at once
				local max_limit = bgNPC.Config.GetTypeLimit(npc_type)
				if max_limit == 0 or (#bgNPC.Actors.GetNPCsByType(npc_type) > max_limit
					and (overloaded or not SeenByAnyPlayer(npc)))
				then
					actor:Remove()
					continue
				end
			end

			-- no teleport or removal mid-scene: they wait until it ends
			if actor.conversation or actor:HasState(BUSY_STATES) then
				continue
			end

			if not IsValidRemovePositionAsync(actor, npc) then
				continue
			end

			if actor.toRemove or not bgn_actors_teleporter then
				if not hook.Run('BGN_PreRemoveNPC', npc) then
					actor:Remove()
				end
			else
				local data = actor:GetData()

				local wanted_level = bgNPC.Config.GetWantedLevel(data)
				if not wanted_level then
					if max_teleporter == current_teleport then break end
					current_teleport = current_teleport + 1

					local is_entered_vehicle = FindExistCarAndEnterThis(actor)
					if not is_entered_vehicle then

						local nodePosition = bgNPC:FindSpawnPositionAsync({ target = npc })
						if nodePosition then
							TeleportActor(actor, nodePosition)
						end
					end
				else
					local desiredPosition
					local wanted_list = WantedModule:GetAllWanted()

					for k = 1, #wanted_list do
						local WantedComponent = wanted_list[k]
						local Target = WantedComponent.target

						if IsValid(Target) and WantedComponent.level >= wanted_level then
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
							local nodePosition = bgNPC:FindSpawnPositionAsync({ position = desiredPosition, target = npc })
							if nodePosition then
								TeleportActor(actor, nodePosition)
							end
						end
					end

				end
			end

		end
	end
end

bgNPC.Tasks.Add('bgn_actors_remover_process', function(yield, wait)
	while true do
		local actors = bgNPC.Actors.GetAll()
		local actors_count = #actors

		yield()

		if actors_count == 0 then
			wait(1)
			continue
		end

		run_remover_process_async(yield, wait, actors, actors_count)
	end
end)

hook.Add('BGN_ResetEnemiesForActor', 'BGN_ClearLevelOnlyNPCs', function(actor)
	if not actor:HasTeam('police') then return end
	if actor.eternal then return end

	local wanted_level = bgNPC.Config.GetWantedLevel(actor:GetData())
	if wanted_level then
		local npc = actor:GetNPC()

		local asset = bgNPC.Modules.Get('wanted')
		local wanted_list = asset:GetAllWanted()
		local success = false

		for i = 1, #wanted_list do
			local WantedClass = wanted_list[i]
			local target = WantedClass.target
			if IsValid(target) and WantedClass.level >= wanted_level then
				success = true
				break
			end
		end

		if not success and not hook.Run('BGN_PreRemoveNPC', npc) then
			bgNPC.Util.Log('Remove wanted npc (reset targets)', 'Wanted NPC')
			actor:Remove()
		end
	end
end)

hook.Add('BGN_WantedLevelDown', 'BGN_ClearCurrentlyLevelOnlyNPCs', function(ent, level)
	for _, actor in ipairs(bgNPC.Actors.GetByTeam('police')) do
		local wanted_level = bgNPC.Config.GetWantedLevel(actor:GetData())

		if wanted_level ~= nil and level < wanted_level then
			actor:RemoveTarget(ent)
		end
	end
end)
