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
    
    if not bgn_enable then
        return
    end

    local bgn_max_npc = GetConVar('bgn_max_npc'):GetInt()
    
    bgNPC:ClearRemovedNPCs()
    
    if #bgNPC:GetAll() < bgn_max_npc then
        for npcType, npc_data in pairs(bgNPC.npc_classes) do
            if not bgNPC:IsActiveNPCType(npcType) then
                goto skip
            end

            local count = table.Count(bgNPC:GetAllNPCsByType(npcType))
            local max = math.Round(((npc_data.fullness / 100) * bgn_max_npc))

            if max <= 0 or count > max then
                goto skip
            end

            bgNPC:SpawnActor(npcType)

            ::skip::
        end
    end
end)