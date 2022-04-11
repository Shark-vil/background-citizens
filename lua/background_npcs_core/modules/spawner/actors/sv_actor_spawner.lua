local bgNPC = bgNPC
local hook = hook
local timer = timer
local player = player
local ents = ents
local IsValid = IsValid
local ipairs = ipairs
local pairs = pairs
local GetConVar = GetConVar
local CurTime = CurTime
local isbool = isbool
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

function bgNPC:RespawnActor(actor)
	if not actor or not actor:IsAlive() then return end

	bgNPC:FindSpawnLocation(actor.uid, nil, nil, function(nodePosition)
		if not actor or not actor:IsAlive() then return end
		if not bgNPC:IsValidSpawnArea(actor:GetType(), nodePosition) then return end

		if not bgNPC:EnterActorInExistVehicle(actor)
			and not bgNPC:SpawnVehicleWithActor(actor)
			and bgNPC:ActorIsStuck(actor)
		then
			bgNPC:RespawnActor(actor)
		end
	end)
end

-- Еб*ный костыль.
hook.Add('BGN_InitActor', 'BGN_RemoveActorTargetFixer', function(actor)
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end

	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local AnotherActor = actors[i]
		local another_npc = AnotherActor:GetNPC()
		if IsValid(another_npc) and another_npc:IsNPC() then
			if actor:HasTeam(AnotherActor) then
				if npc:IsNPC() then npc:AddEntityRelationship(another_npc, D_LI, 99) end
				another_npc:AddEntityRelationship(npc, D_LI, 99)
			else
				if npc:IsNPC() then npc:AddEntityRelationship(another_npc, D_NU, 99) end
				another_npc:AddEntityRelationship(npc, D_NU, 99)
			end
		end
	end

	if npc:IsNPC() then
		for _, ply in ipairs(player.GetAll()) do
			if IsValid(ply) then
				if actor:HasTeam(ply) then
					npc:AddEntityRelationship(ply, D_LI, 99)
				else
					npc:AddEntityRelationship(ply, D_NU, 99)
				end
			end
		end
	end
end)

local function _SetNPCRelationship(actor, npc)
	if not actor:IsAlive() then return end

	local actor_npc = actor:GetNPC()
	local is_ignore_another_npc = GetConVar('bgn_ignore_another_npc'):GetBool()

	local ply = player.GetAll()[1]
	if is_ignore_another_npc or ( ply and npc:Disposition(ply) ~= D_HT ) then
		actor_npc:AddEntityRelationship(npc, D_NU, 99)
		npc:AddEntityRelationship(actor_npc, D_NU, 99)
		actor:RemoveEnemy(npc)
	elseif not is_ignore_another_npc then
		local reaction = actor:GetReactionForProtect()
		if actor:HasStateGroup(reaction, 'danger') then
			actor:SetState(reaction, nil, true)
			actor:AddEnemy(npc)
		end
	end
end

hook.Add('BGN_InitActor', 'BGN_AddAnotherNPCToIgnore', function(actor)
	if not actor:IsAlive() or not actor:GetNPC():IsNPC() then return end

	local entities = ents.GetAll()
	for i = 1, #entities do
		local npc = entities[i]
		if npc and npc:IsNPC() and not npc.isBgnActor then
			_SetNPCRelationship(actor, npc)
		end
	end
end)

hook.Add('OnEntityCreated', 'BGN_AddAnotherNPCToIgnore', function(ent)
	if not ent:IsNPC() then return end

	timer.Simple(0.5, function()
		if not IsValid(ent) or ent.isBgnActor then return end

		local actors = bgNPC:GetAll()
		for i = 1, #actors do
			local actor = actors[i]
			if actor and actor:IsAlive() and actor:GetNPC():IsNPC() then
				_SetNPCRelationship(actor, ent)
			end
		end
	end)
end)

local function InitActorsSpawner(delay)
	timer.Create('BGN_Timer_NPCSpawner', delay, 0, function()
		local bgn_enable = GetConVar('bgn_enable'):GetBool()
		if not bgn_enable or player.GetCount() == 0 then return end

		bgNPC:ClearRemovedNPCs()

		for npcType, npc_data in pairs(bgNPC.cfg.npcs_template) do
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

			bgNPC:FindSpawnLocation(npcType, pos, nil, function(nodePosition)
				if not bgNPC:IsValidSpawnArea(npcType, nodePosition) then return end

				local actor = bgNPC:SpawnActor(npcType, nodePosition)
				if not actor then return end

				if not bgNPC:EnterActorInExistVehicle(actor)
					and not bgNPC:SpawnVehicleWithActor(actor)
					and bgNPC:ActorIsStuck(actor)
				then
					bgNPC:RespawnActor(actor)
				end
			end)
		end
	end)
end

InitActorsSpawner(GetConVar('bgn_spawn_period'):GetFloat())

cvars.AddChangeCallback('bgn_spawn_period', function(_, _, new_value)
	InitActorsSpawner(tonumber(new_value))
end)

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