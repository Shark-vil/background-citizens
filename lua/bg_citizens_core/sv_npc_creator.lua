timer.Create('bgCitizensCreator', 1, 0, function()
    local bg_citizens_enable = GetConVar('bg_citizens_enable'):GetInt()

    if bg_citizens_enable <= 0 then
        return
    end

    local bg_citizens_max_npc = GetConVar('bg_citizens_max_npc'):GetInt()
    local bg_citizens_spawn_radius = GetConVar('bg_citizens_spawn_radius'):GetFloat()
    local bg_citizens_spawn_radius_visibility = GetConVar('bg_citizens_spawn_radius_visibility'):GetFloat()
    local bg_citizens_spawn_radius_ray_tracing = GetConVar('bg_citizens_spawn_radius_ray_tracing'):GetFloat()
    
    bgCitizens:ClearRemovedNPCs()

    if #bgCitizens:GetAll() < bg_citizens_max_npc then
        if #bgCitizens.points ~= 0 then
            local points_close = {}

            for _, v in pairs(bgCitizens.points) do
                for _, ply in pairs(player.GetAll()) do
                    if v.pos:Distance(ply:GetPos()) < bg_citizens_spawn_radius then
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
                        local distance = pos:Distance(ply:GetPos())
                        if distance < bg_citizens_spawn_radius_visibility 
                            and bgCitizens:PlayerIsViewVector(ply, pos)
                        then
                            if distance > bg_citizens_spawn_radius_ray_tracing then
                                local tr = util.TraceLine({
                                    start = ply:EyePos(),
                                    endpos = pos,
                                    filter = function(ent)
                                        if ent ~= ply then 
                                            return true 
                                        end
                                    end
                                })

                                -- print(tr.Entity)
                                if not IsValid(tr.Entity) then
                                    -- print('spawn')
                                    return
                                end
                            end
                            return
                        end
                    end
                    
                    local count = table.Count(bgCitizens:GetAllNPCsByType(npc_data.type))

                    if count > math.Round(((npc_data.fullness / 100) * bg_citizens_max_npc)) then
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

                    for _, ent in pairs(entities) do
                        if IsValid(ent) then
                            if ent:IsPlayer() then
                                npc:AddEntityRelationship(ent, D_NU, 99)
                            elseif ent:IsNPC() then
                                npc:AddEntityRelationship(ent, D_NU, 99)
                                ent:AddEntityRelationship(npc, D_NU, 99)
                            end
                        end
                    end

                    if hook.Run('bgCitizens_PreSpawnNPC', npc, npc_data) ~= nil then
                        npc:Remove()
                        goto skip
                    end

                    npc:Spawn()

                    local actor = BG_NPC_CLASS:Instance(npc, npc_data)
                    actor:SetDefaultState()

                    bgCitizens:AddNPC(actor)

                    npc:SetNWString('bgCitizenType', npc_data.type)

                    hook.Run('bgCitizens_PostSpawnNPC', actor)
                    ::skip::
                end
            end
        end
    end
end)