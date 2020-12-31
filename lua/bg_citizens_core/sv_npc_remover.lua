timer.Create('bgCitizensRemover', 1, 0, function()
    local npcs = bgCitizens:GetAllNPCs()

    if #npcs ~= 0 then
        for _, npc in pairs(npcs) do
            if IsValid(npc) and npc:Health() > 0 then
                local isRemove = true

                for _, ply in pairs(player.GetAll()) do
                    if IsValid(ply) then
                        local npcPos = npc:GetPos()
                        local plyPos = ply:GetPos()
                        if npcPos:Distance(plyPos) < 3000 or bgCitizens:PlayerIsViewVector(ply, npcPos) then
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

        bgCitizens:ClearRemovedNPCs()
    end
end)