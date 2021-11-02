--[[
	------------------------------------------------------------
	Actor - the so-called NPCs that are part of this system.
	------------------------------------------------------------
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
		name - Any NPC name. Displayed in the options menu.
		fullness - the parameter of the world occupancy for each actor (1 to 100)
		limit - alternative for the "fullness" parameter, sets a fixed number of NPCs
		team - the actor's team is used for interaction logic. Explanation above ↑
		weapons - a weapon that an actor can have. If you don't want the actor to have a weapon, leave the list empty or delete the parameter.
		money - the amount of money dropped from the actor after death. The first parameter is the minimum, the second parameter is the maximum (Default used in DarkRP)
		default_models - if true, then the actors will spawn with the standard model mixed with the custom ones. If you want to use only custom models, set the parameter to false
		models - custom actor model. Please note that the model is directly dependent on the class used. If the model is incompatible with the selected class, it can - show an error, not be displayed, the actor can be idle.
		at_ - explanation above ↑
		health - the health that the actor spawns with.
			Can be a number: health = 100
			Can be a table with the possibility of randomness: health = { 100, 200 }
		wanted_level - actors who will spawn only if any entity has the required wanted level. After all the actors have lost their targets, they are removed (1 to 5)
		weapon_skill - The level of circulation of NPCs with weapons. (https://wiki.facepunch.com/gmod/Enums/WEAPON_PROFICIENCY)
		random_skin - enable the creation of random skins for NPCs
		random_bodygroups - enable the creation of random bodygroups for NPCs
		disable_states - disable NPC states switching. Suitable if you need to keep the default logic of the NPC.
		respawn_delay - sets a delay for the appearance of new NPCs after the death of any of the existing
		validator - a function that checks the spawn before the entity is created. Suitable for system checks. For broader checks, use the "BGN_OnValidSpawnActor" or "BGN_PreSpawnActor" hook
--]]

-- NPC classes that fill the streets
bgNPC.cfg.npcs_template = {
	['citizen'] = {
		enabled = true,
		class = 'npc_citizen',
		name = 'Civilian',
		fullness = 64,
		team = { 'residents' },
		weapons = { 'weapon_pistol', 'weapon_357', 'weapon_crowbar' },
		replics = {
			state_groups = {
				['calm'] = 'calm',
			},
			state_names = {
				['fear'] = 'fear',
				['run_from_danger'] = 'fear',
			}
		},
		getting_weapon_chance = 10,
		money = { 0, 100 },
		health = 30,
		weapon_skill = WEAPON_PROFICIENCY_POOR,
		max_vehicle = 2,
		enter_to_exist_vehicle_chance = 10,
		vehicle_group = 'residents',
		vehicles = {
			'sim_fphys_pwavia',
			'sim_fphys_pwgaz52',
			'sim_fphys_pwhatchback',
			'sim_fphys_pwliaz',
			'sim_fphys_pwmoskvich',
			'sim_fphys_pwtrabant',
			'sim_fphys_pwtrabant02',
			'sim_fphys_pwvan',
			'sim_fphys_pwvolga',
			'sim_fphys_pwzaz',
		},
		at_random_range = 110,
		at_random = {
			['walk'] = 80,
			['idle'] = 10,
			['dialogue'] = 10,
			['sit_to_chair'] = 10,
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
	['taxi_driver'] = {
		enabled = true,
		class = 'npc_citizen',
		name = 'Taxi driver',
		limit = 2,
		team = '@citizen',
		weapons = '@citizen',
		replics = '@citizen',
		getting_weapon_chance = '@citizen',
		money = '@citizen',
		health = '@citizen',
		weapon_skill = '@citizen',
		max_vehicle = 2,
		enter_to_exist_vehicle_chance = 100,
		vehicle_group = 'taxi',
		vehicles_random_color = true,
		vehicles = {
			'sim_fphys_dukes',
		},
		at_random_range = '@citizen',
		at_random = '@citizen',
		at_damage_range = '@citizen',
		at_damage = '@citizen',
		at_protect_range = '@citizen',
		at_protect = '@citizen',
		validator = function(self, npc_type)
			if not GetConVar('bgn_enable_dv_support'):GetBool() then
				return false
			end
		end,
	},
	['thief'] = {
		enabled = true,
		inherit = 'citizen',
		class = 'npc_citizen',
		name = 'Thief',
		fullness = 8,
		team = { 'bandits' },
		replics = '@citizen',
		money = { 0, 100 },
		health = 35,
		weapon_skill = WEAPON_PROFICIENCY_POOR,
		enter_to_exist_vehicle_chance = 10,
		at_random_range = 110,
		at_random = {
			['walk'] = 70,
			['idle'] = 10,
			['steal'] = 20,
			['sit_to_chair'] = 10,
		},
		at_damage_range = 100,
		at_damage = {
			['fear'] = 100,
		},
		at_protect_range = 100,
		at_protect = {
			['ignore'] = 100,
		}
	},
	['gangster'] = {
		enabled = true,
		class = 'npc_citizen',
		name = 'Gangster',
		fullness = 10,
		team = { 'bandits' },
		weapons = { 'weapon_pistol', 'weapon_shotgun', 'weapon_ar2', 'weapon_crowbar' },
		money = { 0, 150 },
		health = 50,
		weapon_skill = WEAPON_PROFICIENCY_AVERAGE,
		max_vehicle = 1,
		vehicle_group = 'bandits',
		vehicles = '@citizen',
		enter_to_exist_vehicle_chance = 10,
		at_random_range = 150,
		at_random = {
			['walk'] = 100,
			['idle'] = 25,
			['impingement'] = 5,
			['sit_to_chair'] = 10,
		},
		at_damage_range = 100,
		at_damage = {
			['defense'] = 100,
		},
		at_protect_range = 200,
		at_protect = {
			['ignore'] = 195,
			['defense'] = 5,
		}
	},
	['police'] = {
		enabled = true,
		class = 'npc_metropolice',
		name = 'Police',
		fullness = 6,
		gender = 'male',
		team = { 'residents', 'police' },
		weapons = { 'weapon_pistol' },
		replics = {
			state_names = {
				['defense'] = 'defense_police'
			}
		},
		money = { 0, 170 },
		health = 55,
		weapon_skill = WEAPON_PROFICIENCY_AVERAGE,
		max_vehicle = 1,
		-- vehicle_speed = {
		-- 	['calm'] = 10,
		-- 	['danger'] = 10,
		-- },
		vehicle_multiply_speed = {
			['danger'] = 2,
		},
		vehicle_group = 'police',
		enter_to_exist_vehicle_chance = 30,
		vehicles = {
			'sim_fphys_combineapc'
		},
		random_skin = true,
		random_bodygroups = true,
		at_random_range = 100,
		at_random = {
			['walk'] = 85,
			['idle'] = 10,
			['dialogue'] = 15,
		},
		at_damage_range = 100,
		at_damage = {
			['defense'] = 20,
			['arrest'] = 80
		},
		at_protect_range = 100,
		at_protect = {
			['defense'] = 20,
			['arrest'] = 80
		}
	},
	['civil_defense'] = {
		enabled = true,
		class = 'npc_metropolice',
		name = 'Сivil Defense',
		respawn_delay = 5,
		fullness = 5,
		wanted_level = 2,
		team = { 'residents', 'police' },
		weapons = { 'weapon_smg1' },
		replics = '@police',
		health = { 60, 70 },
		weapon_skill = WEAPON_PROFICIENCY_GOOD,
		vehicle_group = '@police',
		vehicles = '@police',
		enter_to_exist_vehicle_chance = '@police',
		money = { 0, 200 },
		at_random = { ['walk'] = 100 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
	},
	['special_forces'] = {
		enabled = true,
		class = 'npc_combine_s',
		name = 'Special Forces',
		respawn_delay = 15,
		fullness = 5,
		wanted_level = 3,
		team = { 'residents', 'police' },
		weapons = { 'weapon_ar2' },
		replics = '@police',
		health = { 80, 90 },
		weapon_skill = WEAPON_PROFICIENCY_VERY_GOOD,
		max_vehicle = 1,
		vehicle_group = '@police',
		vehicles = {
			'sim_fphys_conscriptapc',
		},
		enter_to_exist_vehicle_chance = '@police',
		random_skin = true,
		random_bodygroups = true,
		default_models = false,
		models = {
			'models/armored_elite/armored_elite_npc.mdl',
		},
		money = { 0, 250 },
		at_random = { ['walk'] = 100 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
	},
	['special_forces_2'] = {
		enabled = true,
		class = 'npc_combine_s',
		name = 'Reinforced Special Forces',
		respawn_delay = 15,
		fullness = 2,
		wanted_level = 4,
		team = { 'residents', 'police' },
		weapons = { 'weapon_shotgun' },
		replics = '@police',
		health = { 100, 110 },
		weapon_skill = WEAPON_PROFICIENCY_PERFECT,
		vehicle_group = '@police',
		vehicles = '@special_forces',
		enter_to_exist_vehicle_chance = '@police',
		money = { 0, 300 },
		at_random = { ['walk'] = 100 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
	},
	['police_helicopter'] = {
		enabled = true,
		class = 'npc_apache_scp_sb',
		name = 'Assault Helicopter',
		disable_states = true,
		respawn_delay = 15,
		limit = 1,
		wanted_level = 5,
		team = { 'residents', 'police' },
		money = { 0, 500 },
		at_damage_range = 100,
		at_damage = { ['defense'] = 100 },
		at_protect_range = 100,
		at_protect = { ['defense'] = 100 },
		validator = function(self, npc_type)
			if list.Get('NPC')[self.class] == nil then
				return false
			end
		end,
	},
	['zombie'] = {
		enabled = false,
		class = {
			'npc_zombie',
			'npc_zombie_torso',
			'npc_fastzombie',
			'npc_poisonzombie',
		},
		name = 'Zombie',
		bio_annihilation_two_replacement = true,
		zombie_mode = true,
		respawn_delay = 10,
		limit = 10,
		team = { 'zombies' },
		money = { 0, 100 },
		health = { 35, 150 },
		random_skin = true,
		random_bodygroups = true,
		at_random = { 
			['walk'] = 70,
			['idle'] = 30,
		},
		at_damage = { ['defense'] = 100 },
		at_protect = { ['defense'] = 100 },
	},
}