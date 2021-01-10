hook.Add('BGN_PreSpawnNPC', 'BGN_SetCustomCitizenTypeFromDefaultModels', function(npc, type, data)
    if type == 'gangster' then
        npc:SetKeyValue('citizentype', 3)
    elseif type == 'citizen' then
        if math.random(0, 10) > 5 then
            npc:SetKeyValue('citizentype', 2)
        end
    end
end)