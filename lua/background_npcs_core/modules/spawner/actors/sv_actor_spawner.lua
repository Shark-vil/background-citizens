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

function bgNPC:RespawnActor(actor, spawn_position)
	if not actor or not actor:IsAlive() then return false end
	if bgNPC:VectorInWater(spawn_position) then return false end

	local npc = actor:GetNPC()

	StopAnimator(npc)
	actor:CallStateAction(nil, 'stop', actor:GetState(), actor:GetStateData())
	actor.anim_action = nil
	actor:ResetSequence()

	npc:SetPos(spawn_position)
	npc:PhysWake()

	local state_data = actor:GetStateData()

	if state_data.updateMovementTypeDelay then
		state_data.updateMovementTypeDelay = 0
	end

	if state_data.updateTargetPointDelay then
		state_data.updateTargetPointDelay = 0
	end

	actor:RandomState()

	hook.Run('BGN_RespawnActor', actor, spawn_position)

	return true
end

local function InitActorsSpawner(delay)
	async.AddDedic('bgn_actors_spawner_process', function(yield, wait)
		wait(delay)

		local bgn_enable = GetConVar('bgn_enable'):GetBool()
		if not bgn_enable or player.GetCount() == 0 then return end

		bgNPC:ClearRemovedNPCs()

		for npcType, npc_data in pairs(bgNPC.cfg.actors) do
			yield()

			if not bgNPC:IsActiveNPCType(npcType) or npc_data.hidden then continue end

			local max_limit = bgNPC:GetLimitActors(npcType)
			if max_limit == 0 or #bgNPC:GetAllNPCsByType(npcType) >= max_limit then continue end

			local pos

			if npc_data.wanted_level ~= nil then
				local asset = bgNPC:GetModule('wanted')
				local success = false
				local wanted_list = asset:GetAllWanted()

				for i = 1, #wanted_list do
					local WantedClass = wanted_list[i]
					local target = WantedClass.target

					if IsValid(target) and WantedClass.level >= npc_data.wanted_level then
						pos = target:GetPos()
						success = true
						break
					end
				end

				if not success then continue end
			end

			if npc_data.validator then
				local result = npc_data.validator(npc_data, npcType)
				if isbool(result) and not result then
					continue
				end
			end

			local spawn_delayer = bgNPC.respawn_actors_delay[npcType]
			if npc_data.respawn_delay and spawn_delayer and spawn_delayer.count ~= 0 then
				if spawn_delayer.time < CurTime() then
					bgNPC.respawn_actors_delay[npcType].time = CurTime() + npc_data.respawn_delay
					bgNPC.respawn_actors_delay[npcType].count = spawn_delayer.count - 1
				else
					continue
				end
			end

			local nodePosition = bgNPC:FindSpawnPosition({ position = pos })
			if nodePosition then
				if not bgNPC:IsValidSpawnArea(npcType, nodePosition) then return end

				local actor = bgNPC:SpawnActor(npcType, nodePosition)
				if not actor then return end

				if bgNPC:ActorIsStuck(actor) then
					actor:RemoveActor()
				elseif not bgNPC:EnterActorInExistVehicle(actor) then
					bgNPC:SpawnVehicleWithActor(actor)
				end
			end
		end

		yield()
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