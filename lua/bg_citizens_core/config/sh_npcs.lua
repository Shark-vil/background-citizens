--[[
	WIKI:
	https://background-npcs.itpony.ru/wiki/Config%20Structure
--]]

--[[
	Actor - the so-called NPCs that are part of this system.

	The name of the table key does not matter. The main thing is the team in which the actor is.
	Teams:
		1. residents - main team for citizens and police. The police will always protect residents.
		2. police - the police are trying to protect everyone. But if the entity is not part of the residents team, they will attack.
		3. player - ignores any player, depending on the config settings may not allow him to inflict damage.
		4. bandits - arbitrary team for troublemakers. At the moment it has no special settings.

	The actions of the actors depend on the settings of the parameters with the prefix at_:
		at_{name}_range - the maximum number parameter for randomizing events (Default - 100)
		at_random - events that are executed randomly if the actor does not have taregts.
		at_damage - events that are performed if the actor takes damage.
		at_protect - events that are performed for other actors, if they see the actor taking damage.

	AT default params:
		ignore - ignores the state change, and leaves the active state.
		idle - the state in which the actor is idle, performing a random animation.
		walk - the state in which the actor moves through the points on the map.
		fear - a state in which the actor tries to escape from the attacker.
		calling_police - a state in which the actor tries to call the police to declare the attacker wanted. After the call, the state will change to "fear"
		defense - a state in which the actor will attack and pursue the attacker.
		impingement - a state in which an actor will try to attack the nearest actor who has no team in common.

	Explanation of other parameters:
		class - NPC class. The class directly affects the playback of animations and the operation of models, use it carefully.
		fullness - the parameter of the world occupancy for each actor (1 to 100)
		team - the actor's team is used for interaction logic. Explanation above ↑
		weapons - a weapon that an actor can have. If you don't want the actor to have a weapon, leave the list empty or delete the parameter.
		money - the amount of money dropped from the actor after death. The first parameter is the minimum, the second parameter is the maximum (Default used in DarkRP)
		defaultModels - if true, then the actors will spawn with the standard model mixed with the custom ones. If you want to use only custom models, set the parameter to false
		models - custom actor model. Please note that the model is directly dependent on the class used. If the model is incompatible with the selected class, it can - show an error, not be displayed, the actor can be idle.
		at_ - explanation above ↑
		health - the health that the actor spawns with.
			Can be a number: health = 100
			Can be a table with the possibility of randomness: health = { 100, 200 }
		wanted_level - actors who will spawn only if any entity has the required wanted level. After all the actors have lost their targets, they are removed (1 to 5)
--]]

-- NPC classes that fill the streets
bgNPC.cfg.npcs_template = {
	['citizen'] = {
		class = 'npc_citizen',
		fullness = 72,
		team = { 'residents' },
		weapons = { 'weapon_pistol', 'weapon_357' },
		money = { 0, 100 },
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
		at_random_range = 100,
		at_random = {
			['walk'] = 90,
			['idle'] = 10,
		},
		at_damage_range = 100,
		at_damage = {
			['fear'] = 90,
			['defense'] = 10,
		},
		at_protect_range = 100,
		at_protect = {
			['fear'] = 70,
			['defense'] = 10,
			['calling_police'] = 20,
		}
	},
	['gangster'] = {
		class = 'npc_citizen',
		fullness = 10,
		team = { 'bandits' },
		weapons = { 'weapon_shotgun', 'weapon_ar2' },
		money = { 0, 150 },
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
		at_random_range = 100,
		at_random = {
			['walk'] = 85,
			['idle'] = 10,
			['impingement'] = 5,
		},
		at_damage_range = 100,
		at_damage = {
			['defense'] = 100,
		},
		at_protect_range = 100,
		at_protect = {
			['ignore'] = 95,
			['defense'] = 5,
		}
	},
	['police'] = {
		class = 'npc_metropolice',
		fullness = 6,
		team = { 'residents', 'police' },
		weapons = { 'weapon_pistol' },
		money = { 0, 170 },
		at_random_range = 100,
		at_random = {
			['walk'] = 90,
			['idle'] = 10,
		},
		at_damage_range = 100,
		at_damage = {
			['defense'] = 100,
		},
		at_protect_range = 100,
		at_protect = {
			['defense'] = 20,
			['arrest'] = 80
		}
	},
	['civil_defense'] = {
		class = 'npc_metropolice',
		fullness = 5,
		wanted_level = 2,
		team = { 'residents', 'police' },
		weapons = { 'weapon_smg1', 'weapon_pistol' },
		health = { 100, 150 },
		money = { 0, 200 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
	},
	['special_forces'] = {
		class = 'npc_combine_s',
		fullness = 5,
		wanted_level = 3,
		team = { 'residents', 'police' },
		weapons = { 'weapon_ar2', 'weapon_shotgun' },
		health = 170,
		money = { 0, 250 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
	},
	['special_hunters'] = {
		class = 'npc_hunter',
		fullness = 2,
		wanted_level = 4,
		team = { 'residents', 'police' },
		money = { 0, 300 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
	},
	--[[
		The police helicopter is temporarily unavailable.
		['police_helicopter'] = {
			class = 'npc_helicopter',
			fullness = 2,
			wanted_level = 5,
			team = { 'residents', 'police' },
			money = { 0, 500 },
			at_damage_range = 100,
			at_damage = { ['defense'] = 100 },
			at_protect_range = 100,
			at_protect = { ['defense'] = 100 },
		},
	]]
}