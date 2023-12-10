local name = slib.language({
	['default'] = 'Сivil Defense (NOT WANTED MODE)',
	['russian'] = 'Гражданская оборона (БЕЗ РЕЖИМА РОЗЫСКА)'
})

bgNPC.cfg:SetActor('civil_defense_nwm', {
	enabled = false,
	inherit = 'police',
	class = 'npc_metropolice',
	name = name,
	respawn_delay = 5,
	fullness = 5,
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