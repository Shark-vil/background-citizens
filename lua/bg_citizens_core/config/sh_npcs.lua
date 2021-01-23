--[[
    WIKI:
    https://background-npcs.itpony.ru/wiki/Config%20Structure
--]]

-- NPC classes that fill the streets
bgNPC.cfg.npcs_template = {
    ['citizen'] = {
        class = 'npc_citizen',
        fullness = 85,
        team = { 'residents' },
        weapons = { 'weapon_pistol', 'weapon_357' },
        money = { 0, 250 },
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
            ['fear'] = 80,
            ['defense'] = 10,
            ['calling_police'] = 10,
        }
    },
    ['gangster'] = {
        class = 'npc_citizen',
        fullness = 10,
        team = { 'bandits' },
        weapons = { 'weapon_shotgun', 'weapon_ar2' },
        money = { 0, 500 },
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
            ['ignore'] = 95,
            ['defense'] = 5,
        }
    },
    ['police'] = {
        class = 'npc_metropolice',
        fullness = 5,
        team = { 'residents', 'police' },
        weapons = { 'weapon_smg1', 'weapon_pistol' },
        money = { 0, 600 },
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 20,
            ['arrest'] = 80
        }
    },
}