hook.Add('PostCleanupMap', 'bgCitizensCleanupNPCsTables', function()
    bgCitizens.actors = {}
    bgCitizens.factors = {}
    bgCitizens.npcs = {}
    bgCitizens.fnpcs = {}
    bgCitizens.wanted = {}
    bgCitizens.arrest_players = {}

    for _, ply in ipairs(player.GetAll()) do
        bgCitizens:SetEntityVariable(ply, 'is_wanted', false, true)
        bgCitizens.killing_statistic[ply] = {}
    end
end)

local function CleanupNPCsIfRemovedOrKilled()
    bgCitizens:ClearRemovedNPCs()
end
hook.Add('bgCitizens_OnKilledActor', 'bgCitizensCleanupNPCsTablesOnNPCKilled', CleanupNPCsIfRemovedOrKilled)
hook.Add('EntityRemoved', 'bgCitizensCleanupNPCsTablesEntityRemoved', CleanupNPCsIfRemovedOrKilled)

timer.Create('bgCitizensRemover', 1, 0, function()
    local npcs = bgCitizens:GetAllNPCs()

    if #npcs ~= 0 then
        local bg_citizens_spawn_radius 
            = GetConVar('bg_citizens_spawn_radius'):GetFloat() ^ 2

        for _, npc in ipairs(npcs) do
            if IsValid(npc) and npc:Health() > 0 then
                local isRemove = true

                for _, ply in ipairs(player.GetAll()) do
                    if IsValid(ply) then
                        local npcPos = npc:GetPos()
                        local plyPos = ply:GetPos()
                        if npcPos:DistToSqr(plyPos) < bg_citizens_spawn_radius 
                            or bgCitizens:PlayerIsViewVector(ply, npcPos)
                        then
                            isRemove = false
                            break
                        end
                    end
                end

                if isRemove then
                    if hook.Run('bgCitizens_PreRemoveNPC', npc) ~= nil then
                        return
                    end
                    npc:Remove()
                end
            end
        end
    end
end)