-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgCitizens.loadPresets = true

-- NPC classes that fill the streets
bgCitizens.npc_classes = {
    {
        class = 'npc_citizen',
        type = 'citizen',
        fullness = 90,
        team = { 'residents' },
        weapons = {'weapon_pistol', 'weapon_357'},
        at_damage = {
            ['fear'] = 90,
            ['defense'] = 10,
        },
        at_protect = {
            ['fear'] = 99,
            ['defense'] = 1,
        }
    },
    {
        class = 'npc_citizen',
        type = 'gangster',
        fullness = 5,
        team = { 'bandits' },
        weapons = {'weapon_pistol', 'weapon_357', 'weapon_shotgun', 'weapon_smg1'},
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['ignore'] = 80,
            ['defense'] = 20,
        }
    },
    {
        class = 'npc_metropolice',
        type = 'police',
        fullness = 5,
        team = { 'residents', 'police' },
        weapons = {'weapon_smg1', 'weapon_pistol'},
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 100,
        }
    }
}

hook.Add('bgCitizens_PreSpawnNPC', 'bgCitizensSetCustomModelFromNPC', function(npc, data)
    if data.type == 'gangster' then
        npc:SetKeyValue('citizentype', 3)
    elseif data.type == 'citizen' then
        if math.random(0, 10) > 5 then
            npc:SetKeyValue('citizentype', 2)
        end
    end
end)