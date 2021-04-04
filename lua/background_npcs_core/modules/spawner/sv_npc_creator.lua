-- Еб*ный костыль.
hook.Add("BGN_InitActor", "BGN_RemoveActorTargetFixer", function(actor)
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

hook.Add("BGN_InitActor", "BGN_AddAnotherNPCToIgnore", function(actor)
	if not GetConVar('bgn_ignore_another_npc'):GetBool() then return end

	local actor_npc = actor:GetNPC()
	if not IsValid(actor_npc) then return end

	local entities = ents.GetAll()
	for i = 1, #entities do
		local npc = entities[i]
		if npc:IsNPC() and not npc.isBgnActor then
			actor:RemoveTarget(npc)

			actor_npc:AddEntityRelationship(npc, D_NU, 99)
			npc:AddEntityRelationship(actor_npc, D_NU, 99)
		end
	end
end)

hook.Add("OnEntityCreated", "BGN_AddAnotherNPCToIgnore", function(ent)
	if not ent:IsNPC() then return end
	if not GetConVar('bgn_ignore_another_npc'):GetBool() then return end

	timer.Simple(0.5, function()
		if not IsValid(ent) then return end
		if ent.isBgnActor then return end

		local actors = bgNPC:GetAll()
		for i = 1, #actors do
			local actor = actors[i]
			local npc = actor:GetNPC()
			if IsValid(npc) then
				actor:RemoveTarget(ent)
				
				ent:AddEntityRelationship(npc, D_NU, 99)
				npc:AddEntityRelationship(ent, D_NU, 99)
			end
		end
	end)
end)

timer.Create('BGN_Timer_NPCSpawner', GetConVar('bgn_spawn_period'):GetFloat(), 0, function()
	local bgn_enable = GetConVar('bgn_enable'):GetBool()
	if not bgn_enable or player.GetCount() == 0 then return end

	bgNPC:ClearRemovedNPCs()

	for npcType, npc_data in pairs(bgNPC.cfg.npcs_template) do
		if not bgNPC:IsActiveNPCType(npcType) then goto skip end

		local max_limit = bgNPC:GetLimitActors(npcType)
		if max_limit == 0 or #bgNPC:GetAllNPCsByType(npcType) >= max_limit then goto skip end

		local pos

		if npc_data.wanted_level ~= nil then
			local asset = bgNPC:GetModule('wanted')
			local success = false
			for target, c_Wanted in pairs(asset:GetAllWanted()) do
				if IsValid(target) and c_Wanted.level >= npc_data.wanted_level then
					pos = target:GetPos()
					success = true
					break
				end
			end

			if not success then goto skip end
		end
		
		if npc_data.validator then
			local result = npc_data.validator(npc_data, npcType)
			if isbool(result) and not result then
				goto skip
			end
		end

		local spawn_delayer = bgNPC.respawn_actors_delay[npcType]
		if npc_data.respawn_delay and spawn_delayer and spawn_delayer.count ~= 0 then
			if spawn_delayer.time < CurTime() then
				bgNPC.respawn_actors_delay[npcType].time = CurTime() + npc_data.respawn_delay
				bgNPC.respawn_actors_delay[npcType].count = spawn_delayer.count - 1
			else
				goto skip
			end
		end

		bgNPC:SpawnActor(npcType, pos)

		::skip::
	end
end)

hook.Add("BGN_InitActor", "BGN_CheckActorSpawnWantedLevel", function(actor)
	if not actor:HasTeam('police') then return end

	local data = actor:GetData()
	if data.wanted_level ~= nil then
		local asset = bgNPC:GetModule('wanted')

		for target, c_Wanted in pairs(asset:GetAllWanted()) do
			if c_Wanted.level >= data.wanted_level then
				actor:AddEnemy(target)
				if actor:GetState() ~= 'defense' then
					actor:SetState('defense')
					bgNPC:Log('Spawn wanted level actor - ' .. actor:GetType(), 'Actor | Spawn')
				end
			end
		end
	end
end)