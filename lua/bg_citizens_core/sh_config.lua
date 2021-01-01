-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgCitizens.loadPresets = true

-- NPC classes that fill the streets
bgCitizens.npc_classes = {
    {
        class = 'npc_citizen',
        type = 'citizen',
        fullness = 85,
        relationship = D_NU,
        team = { 'residents' },
        weapons = {'weapon_pistol', 'weapon_357'},
        at_damage = {
            ['fear'] = 90,
            ['defense'] = 10,
        },
        at_protect = {
            ['fear'] = 90,
            ['defense'] = 10,
        },
        protect = true,
        protect_ignore = {
            'gangster',
        },
        attack = false,
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
            ['ignore'] = 50,
            ['defense'] = 50,
        },
        protect = true,
        protect_ignore = {
            'citizen',
            'police',
        },
        attack = true,
        attack_player = true,
        chance_of_attack = 10,
        attack_ignore = {
            'player',
            'gangster',
            'police'
        }
    },
    {
        class = 'npc_metropolice',
        type = 'police',
        fullness = 10,
        team = { 'residents' },
        friends = {
            'citizen',
        },
        weapons = {'weapon_smg1', 'weapon_pistol'},
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 100,
        },
        protect = true,
        protect_ignore = {},
        attack = false,
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