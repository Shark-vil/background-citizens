local bgNPC = bgNPC
local hook = hook
local player = player
local IsValid = IsValid
local pairs = pairs
local GetConVar = GetConVar
local CurTime = CurTime
local isbool = isbool
local StopAnimator = slib.Animator.Stop
--

local function ActorSpawnOnPosition(npc_type, position)
	if not bgNPC:IsValidSpawnArea(npc_type, position) then return end

	local actor = bgNPC:SpawnActor(npc_type, position)
	if not actor or not actor:IsAlive() then return end

	if not bgNPC:EnterActorInExistVehicle(actor) then
		bgNPC:SpawnVehicleWithActor(actor)
	end

	-- actor:RandomState()
end

function bgNPC:IsValidSpawnArea(actorType, spawnPosition)
	for _, area in pairs(bgNPC.SpawnArea) do
		if spawnPosition:WithinAABox(area.startPoint, area.endPoint) then
			for areaActorType, isValidSpawn in pairs(area.actors) do
				if areaActorType == actorType and not isValidSpawn then
					return false
				end
			end
		end
	end
	return true
end

function bgNPC:RespawnActor(actor, spawn_position, func)
	if not actor or not actor:IsAlive() then
		if func and isfunction(func) then func(false) end
		return
	end

	-- if bgNPC:VectorInWater(spawn_position) then
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
	async.AddDedic('bgn_actors_spawner_process', function(yield, wait)
		while true do
			wait(delay)

			local bgn_enable = GetConVar('bgn_enable'):GetBool()
			if not bgn_enable or player.GetCount() == 0 then continue end

			bgNPC:ClearRemovedNPCs()

			for npc_type, npc_data in pairs(bgNPC.cfg.actors) do
				yield()

				if not bgNPC:IsActiveNPCType(npc_type) or npc_data.hidden then
					yield()
					continue
				end

				local max_limit = bgNPC:GetLimitActors(npc_type)
				if max_limit == 0 or #bgNPC:GetAllNPCsByType(npc_type) >= max_limit then
					yield()
					continue
				end

				local pos

				if npc_data.wanted_level then
					local asset = bgNPC:GetModule('wanted')
					local success = false
					local wanted_list = asset:GetAllWanted()

					for i = #wanted_list, 1, -1 do
						local WantedClass = wanted_list[i]
						if WantedClass then
							local target = WantedClass.target
							if IsValid(target) and WantedClass.level >= npc_data.wanted_level then
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
					ActorSpawnOnPosition(npc_type, node_position)
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

	local data = actor:GetData()
	if data.wanted_level ~= nil then
		local asset = bgNPC:GetModule('wanted')
		local wanted_list = asset:GetAllWanted()

		for i = 1, #wanted_list do
			local WantedClass = wanted_list[i]
			if WantedClass.level >= data.wanted_level then
				actor:AddEnemy(WantedClass.target)
				if actor:GetState() ~= 'defense' then
					actor:SetState('defense')
					bgNPC:Log('Spawn wanted level actor - ' .. actor:GetType(), 'Actor | Spawn')
				end
			end
		end
	end
end)