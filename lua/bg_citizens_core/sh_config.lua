-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgCitizens.loadPresets = true

-- NPC classes that fill the streets
bgCitizens.npc_classes = {
    {
        class = 'npc_citizen',
        type = 'citizen',
        fullness = 70,
        relationship = D_NU
    },
    {
        class = 'npc_citizen',
        type = 'gangster',
        fullness = 20,
        relationship = D_NU
    },
    {
        class = 'npc_metropolice',
        type = 'police',
        fullness = 10,
        relationship = D_NU
    }
}

hook.Add('bgCitizens_PreSpawnNPC', 'bgCitizensSeCustomModelFromNPC', function(npc, data)
    if data.type == 'gangster' then
        npc:SetKeyValue('citizentype', 3)
    elseif data.type == 'citizen' then
        if math.random(0, 10) > 5 then
            npc:SetKeyValue('citizentype', 2)
        end
    end
end)