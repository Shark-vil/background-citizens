--[[
    WIKI:
    https://background-npcs.itpony.ru/wik
--]]

-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgCitizens.loadPresets = true

bgCitizens.wanted_mode = true
bgCitizens.wanted_time = 30

bgCitizens.arrest_moode = true
bgCitizens.arrest_time_limit = 15

-- NPC classes that fill the streets
bgCitizens.npc_classes = {
    {
        class = 'npc_citizen',
        type = 'citizen',
        fullness = 85,
        team = { 'residents' },
        weapons = {'weapon_pistol', 'weapon_357'},
        money = { 0, 250 }, -- does nothing yet
        defaultModels = true,
        models = {
            'models/smalls_civilians/pack1/hoodie_male_01_f_npc.mdl',
            'models/smalls_civilians/pack1/hoodie_male_02_f_npc.mdl',
            'models/smalls_civilians/pack1/hoodie_male_03_f_npc.mdl',
            'models/smalls_civilians/pack1/hoodie_male_04_f_npc.mdl',
            'models/smalls_civilians/pack1/hoodie_male_05_f_npc.mdl',
            'models/smalls_civilians/pack1/hoodie_male_07_f_npc.mdl',
            'models/smalls_civilians/pack1/hoodie_male_09_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_01_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_02_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_03_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_04_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_05_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_07_f_npc.mdl',
            'models/smalls_civilians/pack1/puffer_male_09_f_npc.mdl',
            'models/smalls_civilians/pack1/zipper_female_01_f_npc.mdl',
            'models/smalls_civilians/pack1/zipper_female_02_f_npc.mdl',
            'models/smalls_civilians/pack1/zipper_female_03_f_npc.mdl',
            'models/smalls_civilians/pack1/zipper_female_04_f_npc.mdl',
            'models/smalls_civilians/pack1/zipper_female_06_f_npc.mdl',
            'models/smalls_civilians/pack1/zipper_female_07_f_npc.mdl',
        },
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
        fullness = 10,
        team = { 'bandits' },
        weapons = {'weapon_shotgun', 'weapon_ar2'},
        money = { 0, 500 }, -- does nothing yet
        defaultModels = true,
        models = {
            'models/survivors/npc/amy.mdl',
            'models/survivors/npc/candace.mdl',
            'models/survivors/npc/carson.mdl',
            'models/survivors/npc/chris.mdl',
            'models/survivors/npc/damian.mdl',
            'models/survivors/npc/gregory.mdl',
            'models/survivors/npc/isa.mdl',
            'models/survivors/npc/john.mdl',
            'models/survivors/npc/julius.mdl',
            'models/survivors/npc/lucus.mdl',
            'models/survivors/npc/lyndsay.mdl',
            'models/survivors/npc/margaret.mdl',
            'models/survivors/npc/matt.mdl',
            'models/survivors/npc/rachel.mdl',
            'models/survivors/npc/rufus.mdl',
            'models/survivors/npc/tyler.mdl',
            'models/survivors/npc/wolfgang.mdl'
        },
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
        fullness = 5,
        team = { 'residents', 'police' },
        weapons = {'weapon_smg1', 'weapon_pistol'},
        money = { 0, 600 }, -- does nothing yet
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 50,
            ['arrest'] = 50
        }
    },
--[[
    Too active camera shake. I don't know if it's a bug or not. 
    Temporarily commented out.
    {
        class = 'npc_cscanner',
        type = 'police_cscanner',
        fullness = 2,
        team = { 'residents', 'police' },
        disableStates = true,
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 100,
        }
    }
]]
}