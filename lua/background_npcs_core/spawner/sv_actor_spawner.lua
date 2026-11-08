local StopAnimator = bgNPC.Animator.Stop
--

-- bgNPC:IsValidSpawnArea is defined in modules/spawner/actors/sv_zone_spawner.lua,
-- alongside the rest of the spawn-area/zone system.
function bgNPC:ActorSpawnOnPosition(npc_type, position)
	if not bgNPC:IsValidSpawnArea(npc_type, position) then return end
	if not bgNPC:IsHiddenSpawnPosition(position) then return end

	local actor = bgNPC:SpawnActor(npc_type, position)
	if not actor or not actor:IsAlive() then return end

	if not bgNPC:EnterActorInExistVehicle(actor) then
		bgNPC:SpawnVehicleWithActor(actor)
	end

	-- actor:RandomState()
end

function bgNPC:RespawnActor(actor, spawn_position, func)
	if not actor or not actor:IsAlive() then
		if func and isfunction(func) then func(false) end
		return
	end

	-- if bgNPC.Util.IsVectorInWater(spawn_position) then
	-- 	if func and isfunction(func) then func(false) end
	-- 	return
	-- end

	local npc = actor:GetNPC()
	local old_pos = npc:GetPos()

	npc:SetPos(spawn_position)
	npc:PhysWake()

	timer.Simple(0, function()
		if bgNPC:NPCIsStuck(npc) then
			npc:SetPos(old_pos)
			npc:PhysWake()
			if func and isfunction(func) then func(false) end
			return
		end

		StopAnimator(npc)
		actor:CallStateAction(nil, 'stop', actor:GetState(), actor:GetStateData())
		actor.anim_action = nil
		actor:ResetSequence()

		local state_data = actor:GetStateData()

		if state_data.updateMovementTypeDelay then
			state_data.updateMovementTypeDelay = 0
		end

		if state_data.updateTargetPointDelay then
			state_data.updateTargetPointDelay = 0
		end

		hook.Run('BGN_RespawnActor', actor, spawn_position)

		if func and isfunction(func) then func(true) end
	end)
end

local function InitActorsSpawner(delay)
	bgNPC.Tasks.Add('bgn_actors_spawner_process', function(yield, wait)
		while true do
			wait(delay)

			local bgn_enable = GetConVar('bgn_enable'):GetBool()
			if not bgn_enable or player.GetCount() == 0 then continue end

			bgNPC.Actors.ClearRemoved()

			for npc_type, npc_data in pairs(bgNPC.cfg.actors) do
				yield()

				if not bgNPC.Config.IsTypeActive(npc_type) or npc_data.hidden then
					yield()
					continue
				end

				local max_limit = bgNPC.Config.GetTypeLimit(npc_type)
				if max_limit == 0 or #bgNPC.Actors.GetNPCsByType(npc_type) >= max_limit then
					yield()
					continue
				end

				local pos

				local wanted_level = bgNPC.Config.GetWantedLevel(npc_data)
				if wanted_level then
					local asset = bgNPC.Modules.Get('wanted')
					local success = false
					local wanted_list = asset:GetAllWanted()

					for i = #wanted_list, 1, -1 do
						local WantedClass = wanted_list[i]
						if WantedClass then
							local target = WantedClass.target
							if IsValid(target) and WantedClass.level >= wanted_level then
								pos = target:GetPos()
								success = true
								break
							end
						end
						yield()
					end

					if not success then
						yield()
						continue
					end
				end

				if npc_data.validator then
					local result = npc_data.validator(npc_data, npc_type)
					if isbool(result) and not result then
						yield()
						continue
					end
				end

				local spawn_delayer = bgNPC.respawn_actors_delay[npc_type]
				if npc_data.respawn_delay and spawn_delayer and spawn_delayer.count ~= 0 then
					if spawn_delayer.time < CurTime() then
						bgNPC.respawn_actors_delay[npc_type].time = CurTime() + npc_data.respawn_delay
						bgNPC.respawn_actors_delay[npc_type].count = spawn_delayer.count - 1
					else
						yield()
						continue
					end
				end

				yield()

				local node_position = bgNPC:FindSpawnPositionAsync({ position = pos })
				if node_position then
					bgNPC:ActorSpawnOnPosition(npc_type, node_position)
				end

				yield()
			end
		end
	end)
end

InitActorsSpawner(GetConVar('bgn_spawn_period'):GetFloat())

cvars.AddChangeCallback('bgn_spawn_period', function(_, _, new_value)
	InitActorsSpawner(tonumber(new_value))
end, 'bgn_spawn_period')

hook.Add('BGN_InitActor', 'BGN_CheckActorSpawnWantedLevel', function(actor)
	if not actor:HasTeam('police') then return end

	local wanted_level = bgNPC.Config.GetWantedLevel(actor:GetData())
	if wanted_level then
		local asset = bgNPC.Modules.Get('wanted')
		local wanted_list = asset:GetAllWanted()

		for i = 1, #wanted_list do
			local WantedClass = wanted_list[i]
			if WantedClass.level >= wanted_level then
				actor:AddEnemy(WantedClass.target)
				if actor:GetState() ~= 'defense' then
					actor:SetState('defense')
					bgNPC.Util.Log('Spawn wanted level actor - ' .. actor:GetType(), 'Actor | Spawn')
				end
			end
		end
	end
end)