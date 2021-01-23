hook.Add('BGN_PreSpawnNPC', 'BGN_SetCustomCitizenTypeFromDefaultModels', function(npc, type, data)
    if type == 'gangster' then
        npc:SetKeyValue('citizentype', 3)
    elseif type == 'citizen' then
        if math.random(0, 10) > 5 then
            npc:SetKeyValue('citizentype', 2)
        end
    end
end)

hook.Add('BGN_PreSpawnNPC', 'BGN_SetNPCUpperPosition', function(npc, type, data)
    if type ~= 'npc_helicopter' then return end
    
    local pos = npc:GetPos()
    npc:SetPos(pos + Vector(0, 0, 600))
end)