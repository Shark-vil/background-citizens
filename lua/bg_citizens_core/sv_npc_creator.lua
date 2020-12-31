timer.Create('bgCitizensCreator', 1, 0, function()
    local max_npc_count = GetConVar('bg_citizens_max_npc'):GetInt()
    
    bgCitizens:ClearRemovedNPCs()

    if #bgCitizens:GetAll() < max_npc_count then
        if #bgCitizens.points ~= 0 then
            local points_close = {}

            for _, v in pairs(bgCitizens.points) do
                for _, ply in pairs(player.GetAll()) do
                    if v.pos:Distance(ply:GetPos()) < 3000 then
                        table.insert(points_close, v.pos)
                    end
                end
            end

            if #points_close ~= 0 then
                for _, npc_data in pairs(bgCitizens.npc_classes) do
                    local pos = table.Random(points_close)
                
                    for _, ent in pairs(ents.FindInSphere(pos, 10)) do
                        if IsValid(ent) and ent:IsNPC() then
                            return
                        end
                    end

                    for _, ply in pairs(player.GetAll()) do
                        if pos:Distance(ply:GetPos()) < 2000 and bgCitizens:PlayerIsViewVector(ply, pos) then
                            return
                        end
                    end
                    
                    local count = 0
                    for _, npc in pairs(bgCitizens:GetAllNPCs()) do
                        if IsValid(npc) and npc:GetClass() == npc_data.class then
                            count = count + 1
                        end
                    end

                    if count > math.Round(((npc_data.fullness / 100) * max_npc_count)) then
                        goto skip
                    end

                    if hook.Run('bgCitizens_PreValidSpawnNPC', npc_data) ~= nil then
                        goto skip
                    end

                    local npc = ents.Create(npc_data.class)
                    npc:SetPos(pos)
                    npc:SetSpawnEffect(true)

                    local entities = {}
                    table.Merge(entities, bgCitizens:GetAllNPCs())
                    table.Merge(entities, player.GetAll())

                    if npc_data.relationship ~= nil then
                        for _, ent in pairs(entities) do
                            if IsValid(ent) then
                                if ent:IsPlayer() then
                                    npc:AddEntityRelationship(ent, npc_data.relationship, 99)
                                end

                                if ent:IsNPC() then
                                    if ent:GetClass() == npc_data.class then
                                        npc:AddEntityRelationship(ent, D_LI, 99)
                                        ent:AddEntityRelationship(npc, D_LI, 99)
                                    else
                                        npc:AddEntityRelationship(ent, npc_data.relationship, 99)
                                        ent:AddEntityRelationship(npc, npc_data.relationship, 99)
                                    end
                                end
                            end
                        end
                    else
                        for _, ent in pairs(entities) do
                            if IsValid(ent) and ent:IsNPC() and ent:GetClass() == npc_data.class then
                                npc:AddEntityRelationship(ent, D_LI, 99)
                                ent:AddEntityRelationship(npc, D_LI, 99)
                            end
                        end
                    end

                    if hook.Run('bgCitizens_PreSpawnNPC', npc, npc_data) ~= nil then
                        npc:Remove()
                        goto skip
                    end

                    npc:Spawn()

                    local npc_object = BG_NPC_CLASS:Instance(npc, npc_data)
                    npc_object:SetState('walk', {
                        schedule = SCHED_FORCED_GO,
                        runReset = 0
                    })

                    bgCitizens:AddNPC(npc_object)

                    npc:SetNWString('bgCitizenType', npc_data.type)

                    hook.Run('bgCitizens_PostSpawnNPC', npc)
                    ::skip::
                end
            end
        end
    end
end)