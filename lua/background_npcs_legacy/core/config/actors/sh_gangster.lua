local name = slib.language({
	['default'] = 'Gangster',
	['russian'] = 'Бандит'
})

bgNPC.cfg:SetActor('gangster', {
	enabled = true,
	inherit = 'citizen',
	class = 'npc_citizen',
	name = name,
	fullness = 10,
	team = { 'bandits' },
	weapons = { 'weapon_pistol', 'weapon_shotgun', 'weapon_ar2', 'weapon_crowbar' },
	getting_weapon_chance = false, -- Overrides an inherited setting
	money = { 0, 150 },
	health = 50,
	weapon_skill = WEAPON_PROFICIENCY_AVERAGE,
	max_vehicle = 1,
	vehicle_group = 'bandits',
	enter_to_exist_vehicle_chance = 10,
	at_random_range = 160, -- Obsolete (not in use)
	at_random = {
		['walk'] = 95,
		['idle'] = 25,
		['sit_to_chair'] = 15,
		['impingement'] = 5,
		['random_gesture'] = 10,
	},
	at_damage_range = 100, -- Obsolete (not in use)
	at_damage = {
		['defense'] = 100,
	},
	at_protect_range = 200, -- Obsolete (not in use)
	at_protect = {
		['ignore'] = 195,
		['defense'] = 5,
	}
})