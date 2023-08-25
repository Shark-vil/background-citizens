local bgNPC = bgNPC
local hook = hook
local player = player
local GetConVar = GetConVar
local IsValid = IsValid
local ipairs = ipairs
local coroutine_yield = coroutine.yield
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
	bgNPC:RemoveNPC(ent)
end)

local function FindExistCarAndEnterThis(actor)
	if not bgNPC:EnterActorInExistVehicle(actor) then
		return bgNPC:SpawnVehicleWithActor(actor)
	end
	return true
end

local function TeleportActor(actor, pos)
	if not actor or not bgNPC:IsValidSpawnArea(actor:GetType(), pos) then return end

	bgNPC:RespawnActor(actor, pos)
end

local function IsValidRemovePositionAsync(actor, npc)
	local npc_pos = npc:GetPos()

	for player_index = 1, #player_list do
		local ply = player_list[player_index]
		if not IsValid(ply) then continue end

		coroutine_yield()

		local ply_pos = ply:GetPos()
		local dist = npc_pos:DistToSqr(ply_pos)

		if dist > bgn_spawn_radius then
			if ply:slibIsTraceEntity(npc, dist, true) then
				return false
			end
		else
			if dist <= bgn_spawn_block_radius or dist <= bgn_spawn_radius_visibility then
				return false
			end

			coroutine_yield()

			if not actor.toRemove and slib.chance(50) then
				return false
			end

			coroutine_yield()

			if ply:slibIsTraceEntity(npc, dist, true) then
				return false
			end
		end
	end

	return true
end

async.AddDedic('bgn_actors_remover_process', function(yield, wait)
	while true do
		local actors = bgNPC:GetAll()
		local actors_count = #actors

		yield()

		if actors_count == 0 then
			wait(1)
			return
		end

		local WantedModule = bgNPC:GetModule('wanted')

		yield()

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

		yield()

		for i = 1, actors_count do
			yield()

			local actor = actors[i]

			if not fasted_teleport then
				yield()
			end

			if not actor or not actor:IsAlive() or actor.eternal or actor.debugger or actor.data.hidden then
				continue
			end

			local npc = actor:GetNPC()
			local npc_type = actor:GetType()

			if not bgn_enable or player_count == 0 or not bgNPC:IsActiveNPCType(npc_type) then
				if not hook.Run('BGN_PreRemoveNPC', npc) then
					actor:Remove()
				end
			else
				if not actor.mechanics.ignore_limit then
					local max_limit = bgNPC:GetLimitActors(npc_type)
					if max_limit == 0 or #bgNPC:GetAllNPCsByType(npc_type) > max_limit then
						actor:Remove()
						yield()
						continue
					end
				end

				if not IsValidRemovePositionAsync(actor, npc) then
					yield()
					continue
				end

				if actor.toRemove or not bgn_actors_teleporter then
					if not hook.Run('BGN_PreRemoveNPC', npc) then
						actor:Remove()
					end
					yield()
				else
					local data = actor:GetData()

					if data.wanted_level == nil then
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

							if IsValid(Target) and WantedComponent.level >= data.wanted_level then
								desiredPosition = Target:GetPos()
								break
							end

							yield()
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

						yield()
					end
				end

				yield()
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