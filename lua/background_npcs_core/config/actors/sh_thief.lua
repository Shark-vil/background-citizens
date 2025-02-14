local name = slib.language({
	['default'] = 'Thief',
	['russian'] = 'Воришка'
})

bgNPC.cfg:SetActor('thief', {
	enabled = true,
	inherit = 'citizen',
	class = 'npc_citizen',
	name = name,
	fullness = 8,
	team = { 'bandits' },
	getting_weapon_chance = 10,
	money = { 0, 100 },
	health = 35,
	enter_to_exist_vehicle_chance = 10,
	at_random_range = 120, -- Obsolete (not in use)
	at_random = {
		['walk'] = 70,
		['idle'] = 10,
		['steal'] = 20,
		['sit_to_chair'] = 10,
		['random_gesture'] = 10,
	},
	at_damage_range = 100, -- Obsolete (not in use)
	at_damage = {
		['fear'] = 100,
	},
	at_protect_range = 100, -- Obsolete (not in use)
	at_protect = {
		['ignore'] = 100,
	}
})