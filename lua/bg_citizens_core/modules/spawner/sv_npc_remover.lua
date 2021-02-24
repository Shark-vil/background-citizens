hook.Add('PostCleanupMap', 'BGN_ResetAllGlobalTablesAndVariables', function()
	bgNPC.actors = {}
	bgNPC.factors = {}
	bgNPC.npcs = {}
	bgNPC.fnpcs = {}
end)

local function CleanupNPCsIfRemovedOrKilled()
	bgNPC:ClearRemovedNPCs()
end
hook.Add('BGN_OnKilledActor', 'BGN_CleanupNPCsTablesOnNPCKilled', CleanupNPCsIfRemovedOrKilled)
hook.Add('EntityRemoved', 'BGN_CleanupNPCsTablesOnEntityRemoved', CleanupNPCsIfRemovedOrKilled)

timer.Create('BGN_Timer_NPCRemover', 1, 0, function()
	local actors = bgNPC:GetAll()

	if #actors == 0 then return end

	local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	local bgn_enable = GetConVar('bgn_enable'):GetBool()

	for _, actor in ipairs(actors) do
		if actor:IsAlive() then
			local npc = actor:GetNPC()

			if not bgn_enable or player.GetCount() == 0 or not bgNPC:IsActiveNPCType(actor:GetType()) then
				if not hook.Run('BGN_PreRemoveNPC', npc) then
					bgNPC:RemoveNPC(npc)
					npc:Remove()
				end
			else
				local isRemove = true

				for _, ply in ipairs(player.GetAll()) do
					if IsValid(ply) then
						local npcPos = npc:GetPos()
						local plyPos = ply:GetPos()
						if npcPos:DistToSqr(plyPos) < bgn_spawn_radius 
							or bgNPC:PlayerIsViewVector(ply, npcPos)
						then
							isRemove = false
							break
						end
					end
				end

				if isRemove then
					if not hook.Run('BGN_PreRemoveNPC', npc) then
						bgNPC:RemoveNPC(npc)
						npc:Remove()
					end
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

		if not hook.Run('BGN_PreRemoveNPC', npc) then
			bgNPC:Log('Remove wanted npc (reset targets)', 'Wanted NPC')
			bgNPC:RemoveNPC(npc)
			npc:Remove()
		end
	end
end)

hook.Add("BGN_WantedLevelDown", "BGN_ClearCurrentlyLevelOnlyNPCs", function(ent, level)
	for _, actor in ipairs(bgNPC:GetAllByTeam('police')) do
		local wanted_level = actor:GetData().wanted_level

		if wanted_level ~= nil then
			if level < wanted_level then
				actor:RemoveTarget(ent)
			end
		end
	end
end)