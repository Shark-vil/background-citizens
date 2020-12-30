timer.Create('bgCitizensRemover', 1, 0, function()
    if #bgCitizens.npcs ~= 0 then
        for _, npc in pairs(bgCitizens.npcs) do
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

        local new_table = {}
        for _, npc in pairs(bgCitizens.npcs) do
            if IsValid(npc) and npc:Health() > 0 then
                table.insert(new_table, npc)
            end
        end

        bgCitizens.npcs = new_table
    end
end)