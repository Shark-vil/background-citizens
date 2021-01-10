hook.Add('PostCleanupMap', 'BGN_ResetAllGlobalTablesAndVariables', function()
	bgNPC.actors = {}
	bgNPC.factors = {}
	bgNPC.npcs = {}
	bgNPC.fnpcs = {}
	bgNPC.wanted = {}
	bgNPC.arrest_players = {}

	bgNPC:ClearWanted()

	for _, ply in ipairs(player.GetAll()) do
		bgNPC:SetEntityVariable(ply, 'is_wanted', false, true)
		bgNPC.killing_statistic[ply] = {}
	end
end)

local function CleanupNPCsIfRemovedOrKilled()
	bgNPC:ClearRemovedNPCs()
end
hook.Add('BGN_OnKilledActor', 'BGN_CleanupNPCsTablesOnNPCKilled', CleanupNPCsIfRemovedOrKilled)
hook.Add('EntityRemoved', 'BGN_CleanupNPCsTablesOnEntityRemoved', CleanupNPCsIfRemovedOrKilled)

timer.Create('BGN_Timer_NPCRemover', 1, 0, function()
	local npcs = bgNPC:GetAllNPCs()

	if #npcs ~= 0 then
		local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2

		local bgn_enable = GetConVar('bgn_enable'):GetBool()

		for _, npc in ipairs(npcs) do
			if IsValid(npc) and npc:Health() > 0 then
				if not bgn_enable or #player.GetAll() == 0 then
					npc:Remove()
				else
					local isRemove = true

					for _, ply in ipairs(player.GetAll()) do
						if not IsValid(ply) then continue end

						local npcPos = npc:GetPos()
						local plyPos = ply:GetPos()
						if npcPos:DistToSqr(plyPos) < bgn_spawn_radius
							or bgNPC:PlayerIsViewVector(ply, npcPos)
						then
							isRemove = false
							break
						end
					end

					if isRemove then
						if not hook.Run('BGN_PreRemoveNPC', npc) then
							return
						end
						npc:Remove()
					end
				end
			end
		end
	end
end)