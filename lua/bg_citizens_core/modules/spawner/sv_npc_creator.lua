hook.Add("OnEntityCreated", "BGN_OnAnotherEntityCreatedEvent", function(ent)
    if ent:IsNPC() then
        if GetConVar('bgn_ignore_another_npc'):GetBool() then
            timer.Simple(1, function()
                if not IsValid(ent) then return end
                if not ent.isBgnActor then
                    for _, actor in ipairs(bgNPC:GetAll()) do
                        local npc = actor:GetNPC()
                        if IsValid(npc) then
                            actor:RemoveTarget(ent)
                            ent:AddEntityRelationship(npc, D_NU, 99)
                            npc:AddEntityRelationship(ent, D_NU, 99)
                            ent.bgNPCIgnore = true
                        end
                    end
                end
            end)
        end
    end
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