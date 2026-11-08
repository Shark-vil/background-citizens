local name = bgNPC.Util.Lang({
	['default'] = 'Medic',
	['russian'] = 'Врач'
})

-- Spawned only by bgNPC.Medics (systems/sv_medics.lua) when an actor dies; with Decent Vehicle and a car in
-- "vehicles" a medic comes by ambulance (siren on, shortest way, like the police chasing).
bgNPC.cfg:SetActor('medic', {
	enabled = true,
	inherit = 'citizen',
	class = 'npc_citizen',
	name = name,
	limit = 4, -- two pairs (systems/sv_medics.lua)
	team = { 'residents', 'medics' },
	weapons = {},
	getting_weapon_chance = false,
	health = 50,
	models = {
		'models/humans/group03m/male_01.mdl', 'models/humans/group03m/male_02.mdl',
		'models/humans/group03m/male_03.mdl', 'models/humans/group03m/male_04.mdl',
		'models/humans/group03m/male_06.mdl', 'models/humans/group03m/male_07.mdl',
		'models/humans/group03m/female_01.mdl', 'models/humans/group03m/female_02.mdl',
		'models/humans/group03m/female_03.mdl', 'models/humans/group03m/female_04.mdl',
	},
	max_vehicle = 2,
	enter_to_exist_vehicle_chance = 0,
	-- npc_dvbgn_police drives to actor.drive_target_pos; two seats taken: the medic and its partner
	vehicle_group = 'medics|npc_dvbgn_police|ambulance|2',
	vehicles = {},
	vehicles_random_color = false,
	at_damage = { ['fear'] = 100 },
	at_protect = { ['ignore'] = 100 }, -- on duty: other people's fights (and the wanted) are not their business
	validator = function() return false end, -- never spawned by the regular spawner
})
