bgNPC.cfg:SetActor('zombie', {
	enabled = false,
	class = {
		'npc_zombie',
		'npc_zombie_torso',
		'npc_fastzombie',
		'npc_poisonzombie',
	},
	name = 'Zombie',
	zombie_mode = true,
	respawn_delay = 10,
	limit = 10,
	team = { 'zombies' },
	money = { 0, 100 },
	health = { 35, 150 },
	random_skin = true,
	random_bodygroups = true,
	at_random = { ['walk'] = 70, ['idle'] = 30 },
	at_damage = { ['defense'] = 100 },
	at_protect = { ['defense'] = 100 },
	relationship = {
		['@player'] = D_HT,
		['@actor'] = D_HT,
		['@team'] = D_LI,
		['@npc'] = D_HT,
	}
})