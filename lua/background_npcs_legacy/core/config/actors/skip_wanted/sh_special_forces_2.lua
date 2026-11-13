local name = slib.language({
	['default'] = 'Reinforced Special Forces (NOT WANTED MODE)',
	['russian'] = 'Усиленный спецназ (БЕЗ РЕЖИМА РОЗЫСКА)'
})

bgNPC.cfg:SetActor('special_forces_2_nwm', {
	enabled = false,
	inherit = 'special_forces',
	class = 'npc_combine_s',
	name = name,
	respawn_delay = 15,
	fullness = 2,
	weapons = { 'weapon_shotgun' },
	health = { 100, 110 },
	weapon_skill = WEAPON_PROFICIENCY_PERFECT,
	money = { 0, 300 },
})