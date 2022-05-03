local name = slib.language({
	['default'] = 'Сivil Defense',
	['russian'] = 'Гражданская оборона'
})

bgNPC.cfg:SetActor('civil_defense', {
	enabled = true,
	inherit = 'police',
	class = 'npc_metropolice',
	name = name,
	respawn_delay = 5,
	fullness = 5,
	wanted_level = 2,
	weapons = { 'weapon_smg1' },
	health = { 60, 70 },
	weapon_skill = WEAPON_PROFICIENCY_GOOD,
	money = { 0, 200 },
	at_random = { ['walk'] = 100 },
	at_damage_range = 100,
	at_damage = { ['defense'] = 100 },
	at_protect_range = 100,
	at_protect = { ['defense'] = 100 },
})