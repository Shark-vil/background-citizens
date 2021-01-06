-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgCitizens.loadPresets = true

bgCitizens.wanted_mode = true
bgCitizens.wanted_time = 30

-- NPC classes that fill the streets
bgCitizens.npc_classes = {
    {
        class = 'npc_citizen',
        type = 'citizen',
        fullness = 85,
        team = { 'residents' },
        weapons = {'weapon_pistol', 'weapon_357'},
        money = { 0, 250 }, -- does nothing yet
        at_damage = {
            ['fear'] = 90,
            ['defense'] = 10,
        },
        at_protect = {
            ['fear'] = 50,
            ['defense'] = 10,
            ['calling_police'] = 40,
        }
    },
    {
        class = 'npc_citizen',
        type = 'gangster',
        fullness = 5,
        team = { 'bandits' },
        weapons = {'weapon_shotgun', 'weapon_ar2'},
        money = { 0, 500 }, -- does nothing yet
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['ignore'] = 99,
            ['defense'] = 1,
        }
    },
    {
        class = 'npc_metropolice',
        type = 'police',
        fullness = 10,
        team = { 'residents', 'police' },
        weapons = {'weapon_smg1', 'weapon_pistol'},
        money = { 0, 600 }, -- does nothing yet
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 100,
        }
    }
}