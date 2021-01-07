timer.Create('BGN_FixNPCRelationship', 1, 0, function()
    local actors = bgCitizens:GetAll()

    for _, ActorOne in ipairs(actors) do
        local npc_1 = ActorOne:GetNPC()
        for _, ActorTwo in ipairs(actors) do
            if ActorOne ~= ActorTwo then
                local npc_2 = ActorTwo:GetNPC()

                if IsValid(npc_1) and IsValid(npc_2) then
                    if ActorOne:HasTeam(ActorTwo) then
                        if npc_1:Disposition(npc_2) ~= D_NU 
                            or npc_2:Disposition(npc_1) ~= D_NU
                        then
                            npc_1:AddEntityRelationship(npc_2, D_NU, 99)
                            npc_2:AddEntityRelationship(npc_1, D_NU, 99)
                        end
                    end
                end
            end
        end
    end
end)