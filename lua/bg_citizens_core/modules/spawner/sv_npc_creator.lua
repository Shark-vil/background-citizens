timer.Create('BGN_Timer_NPCSpawner', GetConVar('bgn_spawn_period'):GetFloat(), 0, function()
    local bgn_enable = GetConVar('bgn_enable'):GetInt()

    if bgn_enable <= 0 then
        return
    end

    local bgn_max_npc = GetConVar('bgn_max_npc'):GetInt()
    
    bgNPC:ClearRemovedNPCs()
    
    if #bgNPC:GetAll() < bgn_max_npc then
        for _, npc_data in ipairs(bgNPC.npc_classes) do
            if not bgNPC:IsActiveNPCType(npc_data.type) then
                goto skip
            end

            local count = table.Count(bgNPC:GetAllNPCsByType(npc_data.type))
            local max = math.Round(((npc_data.fullness / 100) * bgn_max_npc))

            if max <= 0 or count > max then
                goto skip
            end

            bgNPC:SpawnActor(npc_data.type)

            ::skip::
        end
    end
end)