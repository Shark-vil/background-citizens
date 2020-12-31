timer.Create('bgCitizensCreator', 1, 0, function()
    local max_npc_count = GetConVar('bg_citizens_max_npc'):GetInt()
    local npcs_count = #bgCitizens.npcs
    local fnpcs_count = #bgCitizens.fnpcs

    if npcs_count > 0 then
        for i = npcs_count, 1, -1 do
            if not IsValid(bgCitizens.npcs[i]) then
                table.remove(bgCitizens.npcs, i)
            end
        end
    end

    if fnpcs_count > 0 then
        for i = fnpcs_count, 1, -1 do
            if not IsValid(bgCitizens.fnpcs[i]) then
                table.remove(bgCitizens.fnpcs, i)
            end
        end
    end

    if npcs_count < max_npc_count then
        if #bgCitizens.points ~= 0 then
            local points_close = {}

            for _, v in ipairs(bgCitizens.points) do
                for _, ply in ipairs(player.GetAll()) do
                    if v.pos:DistToSqr(ply:GetPos()) < 3000000 then
                        table.insert(points_close, v.pos)
                    end
                end
            end

            if #points_close ~= 0 then
                for _, npc_object in ipairs(bgCitizens.npc_classes) do
                    local pos = table.Random(points_close)
                
                    for _, ent in ipairs(ents.FindInSphere(pos, 10)) do
                        if IsValid(ent) and ent:IsNPC() then
                            return
                        end
                    end

                    for _, ply in ipairs(player.GetAll()) do
                        if pos:DistToSqr(ply:GetPos()) < 2000000 and bgCitizens:PlayerIsViewVector(ply, pos) then
                            return
                        end
                    end
                    
                    local count = 0
                    for _, npc in ipairs(bgCitizens.npcs) do
                        if IsValid(npc) and npc:GetClass() == npc_object.class then
                            count = count + 1
                        end
                    end

                    if count > math.Round(((npc_object.fullness / 100) * max_npc_count)) then
                        goto skip
                    end

                    if hook.Run('bgCitizens_PreValidSpawnNPC', npc_object) ~= nil then
                        goto skip
                    end

                    local npc = ents.Create(npc_object.class)
                    npc:SetPos(pos)
                    npc:SetSpawnEffect(true)

                    local entities = {}
                    table.Merge(entities, bgCitizens.npcs)
                    table.Merge(entities, player.GetAll())

                    if npc_object.relationship ~= nil then
                        for _, ent in ipairs(entities) do
                            if IsValid(ent) then
                                if ent:IsPlayer() then
                                    npc:AddEntityRelationship(ent, npc_object.relationship, 99)
                                end

                                if ent:IsNPC() then
                                    if ent:GetClass() == npc_object.class then
                                        npc:AddEntityRelationship(ent, D_LI, 99)
                                        ent:AddEntityRelationship(npc, D_LI, 99)
                                    else
                                        npc:AddEntityRelationship(ent, npc_object.relationship, 99)
                                        ent:AddEntityRelationship(npc, npc_object.relationship, 99)
                                    end
                                end
                            end
                        end
                    else
                        for _, ent in ipairs(entities) do
                            if IsValid(ent) and ent:IsNPC() and ent:GetClass() == npc_object.class then
                                npc:AddEntityRelationship(ent, D_LI, 99)
                                ent:AddEntityRelationship(npc, D_LI, 99)
                            end
                        end
                    end

                    npc.bgCitizenType = npc_object.type
                    npc.bgCitizenState = { 
                        state = 'walk', 
                        data = {
                            schedule = SCHED_FORCED_GO,
                            runReset = 0
                        } 
                    }
                    
                    function npc:bgCitizenTaskClear()
                        self:ClearSchedule()
                    end

                    function npc:bgCitizenStateUpdate(state, data)
                        self.bgCitizenState = { state = state, data = (data or {}) }
                        return self.bgCitizenState
                    end

                    function npc:GetState()
                        return self.bgCitizenState.state
                    end

                    function npc:GetStateData()
                        return self.bgCitizenState.data
                    end

                    if hook.Run('bgCitizens_PreSpawnNPC', npc, npc_object) ~= nil then
                        npc:Remove()
                        goto skip
                    end

                    npc:Spawn()

                    table.insert(bgCitizens.npcs, npc)
                    bgCitizens.fnpcs[npc_object.type] = bgCitizens.fnpcs[npc_object.type] or {}
                    table.insert(bgCitizens.fnpcs[npc_object.type], npc)

                    hook.Run('bgCitizens_PostSpawnNPC', npc)

                    ::skip::
                end
            end
        end
    end
end)
