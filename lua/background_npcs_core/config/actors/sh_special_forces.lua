local name = slib.language({
	['default'] = 'Special Forces',
	['russian'] = 'Спецназ'
})

bgNPC.cfg:SetActor('special_forces', {
	enabled = true,
	inherit = 'civil_defense',
	class = 'npc_combine_s',
	name = name,
	respawn_delay = 15,
	fullness = 5,
	wanted_level = 3,
	weapons = { 'weapon_ar2' },
	health = { 80, 90 },
	weapon_skill = WEAPON_PROFICIENCY_VERY_GOOD,
	max_vehicle = 1,
	vehicles = { 'sim_fphys_conscriptapc' },
	random_skin = true,
	random_bodygroups = true,
	default_models = false,
	models = { 'models/armored_elite/armored_elite_npc.mdl' },
	money = { 0, 250 },
})