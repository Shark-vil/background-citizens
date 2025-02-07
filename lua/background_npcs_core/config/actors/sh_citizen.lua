local name = slib.language({
	['default'] = 'Civilian',
	['russian'] = 'Житель'
})

bgNPC.cfg:SetActor('citizen', {
	enabled = true,
	class = 'npc_citizen',
	name = name,
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
	vehicle_multiply_speed = { ['danger'] = 4 },
	getting_weapon_chance = 30,
	money = { 0, 100 },
	health = 30,
	weapon_skill = WEAPON_PROFICIENCY_POOR,
	max_vehicle = 2,
	enter_to_exist_vehicle_chance = 10,
	vehicles_strict_color_chance = 0,
	vehicles_random_color = false,
	vehicles_random_skin = true,
	vehicles_random_bodygroups = true,
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
	start_random_state = true,
	at_random_range = 120, -- Obsolete (not in use)
	at_random = {
		['walk'] = 50,
		['idle'] = 15,
		['dialogue'] = 20,
		['sit_to_chair'] = 20,
		['random_gesture'] = 15,
	},
	at_damage_range = 100, -- Obsolete (not in use)
	at_damage = {
		['fear'] = 90,
		['defense'] = 10,
	},
	at_protect_range = 100, -- Obsolete (not in use)
	at_protect = {
		['fear'] = 70,
		['defense'] = 10,
		['calling_police'] = 20,
	}
})