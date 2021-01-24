hook.Add("BGN_PostSpawnNPC", "BGN_AddAnotherNPCToIgnore", function(actor)
	if not GetConVar('bgn_ignore_another_npc'):GetBool() then return end

	local actor_npc = actor:GetNPC()
	if not IsValid(actor_npc) then return end

	for _, npc in ipairs(ents.FindByClass('npc_*')) do
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

		for _, actor in ipairs(bgNPC:GetAll()) do
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
	
	if not bgn_enable or player.GetCount() == 0 then
		return
	end

	local bgn_max_npc = GetConVar('bgn_max_npc'):GetInt()
	
	bgNPC:ClearRemovedNPCs()
	
	if #bgNPC:GetAll() < bgn_max_npc then
		for npcType, npc_data in pairs(bgNPC.cfg.npcs_template) do
			if not bgNPC:IsActiveNPCType(npcType) then
				goto skip
			end

			if npc_data.fullness ~= nil then
				local count = table.Count(bgNPC:GetAllNPCsByType(npcType))
				local max = math.Round(((npc_data.fullness / 100) * bgn_max_npc))

				if max <= 0 or count > max then
					goto skip
				end

				if npc_data.wanted_level ~= nil then
					local asset = bgNPC:GetModule('wanted')
					local success = false
					for target, c_Wanted in pairs(asset:GetAllWanted()) do
						if c_Wanted.level >= npc_data.wanted_level then
							success = true
							break
						end
					end

					if not success then
						goto skip
					end
				end

				bgNPC:SpawnActor(npcType)
			end

			::skip::
		end
	end
end)

hook.Add("BGN_PostSpawnNPC", "BGN_CheckActorSpawnWantedLevel", function(actor)
	if not actor:HasTeam('police') then return end

	local data = actor:GetData()
	if data.wanted_level ~= nil then
		local asset = bgNPC:GetModule('wanted')

		for target, c_Wanted in pairs(asset:GetAllWanted()) do
			if c_Wanted.level >= data.wanted_level then
				actor:AddTarget(target)
				if actor:GetState() ~= 'defense' then
					actor:Defense()
					bgNPC:Log('Spawn wanted level actor - ' .. actor:GetType(), 'Actor | Spawn')
				end
			end
		end
	end
end)

hook.Add("BGN_ResetTargetsForActor", "BGN_ClearLevelOnlyNPCs", function(actor)
	if not actor:HasTeam('police') then return end

	local data = actor:GetData()
	if data.wanted_level ~= nil then
		local npc = actor:GetNPC()

		if hook.Run('BGN_PreRemoveNPC', npc) ~= nil then
			return
		end

		npc:Remove()
	end
end)