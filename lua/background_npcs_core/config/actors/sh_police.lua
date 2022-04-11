bgNPC.cfg:SetActor('police', {
	enabled = true,
	inherit = 'citizen',
	class = 'npc_metropolice',
	name = 'Police',
	fullness = 6,
	gender = 'male',
	team = { 'residents', 'police' },
	weapons = { 'weapon_pistol' },
	getting_weapon_chance = false, -- Overrides an inherited setting
	replics = {
		state_names = {
			['defense'] = 'defense_police'
		}
	},
	money = { 0, 170 },
	health = 55,
	weapon_skill = WEAPON_PROFICIENCY_AVERAGE,
	max_vehicle = 1,
	vehicle_multiply_speed = { ['danger'] = 2 },
	models = false, -- Overrides an inherited setting
	vehicle_group = 'police',
	enter_to_exist_vehicle_chance = 30,
	vehicles = { 'sim_fphys_combineapc' },
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
})