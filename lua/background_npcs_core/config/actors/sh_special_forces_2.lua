bgNPC.cfg:SetActor('special_forces_2', {
	enabled = true,
	inherit = 'special_forces',
	class = 'npc_combine_s',
	name = 'Reinforced Special Forces',
	respawn_delay = 15,
	fullness = 2,
	wanted_level = 4,
	weapons = { 'weapon_shotgun' },
	health = { 100, 110 },
	weapon_skill = WEAPON_PROFICIENCY_PERFECT,
	money = { 0, 300 },
})