--[[
	Scenic NPCs: staged scenes that appear on the map by themselves (systems/scenic/).
	A scene is data; a spot finder looks for a place that fits it, so nothing here depends on the map.

	Scene fields:
		place   where the scene can stand (finders: systems/scenic/sv_scenic_finders.lua)
		          floor  flat floor          sky   flat floor under the open sky
		          wall   flat wall, the actors stand with their backs to it (yaw 180 - face it)
		          door   a closed door, the actors stand in front of it facing it (yaw 180 - turn away)
		          chair  a chair prop of bgNPC.cfg.sit_chairs or a custom seat
		weight  relative chance (default 10)
		gap     distance to the wall or to the door (default 22 / 40)
		ttl     seconds before the unseen scene is cleaned up (default 600)
		group   the first member is repeated min..max times: step = Vector shift of every next copy
		        (forward, right, up), ring = radius of a loose cluster
		members one actor each:
		          type    actor type of the config (any body: an NPC and a NextBot play the same sequences)
		          seq     sequence or a list of them; the first the model has is played, a looped one
		          pos     Vector(forward, right, up) from the scene spot, yaw - turn from the spot angle
		          models  model list (default: the actor config)
		          weapon  item taken in hand (a suitcase, a ration box)
		          seat    placed on the chair of the spot (place = 'chair')
		props   decor created with the scene: model, pos, yaw, solid (default true)
--]]

local function V(forward, right, up)
	return Vector(forward or 0, right or 0, up or 0)
end

-- the couch sequences exist on the standard rigs only (the config models may be custom ones)
local COUPLE_MALE = {
	'models/humans/group01/male_09.mdl', 'models/humans/group02/male_09.mdl',
	'models/humans/group03/male_09.mdl', 'models/humans/group03m/male_09.mdl',
}
local COUPLE_FEMALE = {
	'models/humans/group01/female_01.mdl', 'models/humans/group02/female_01.mdl',
	'models/humans/group03/female_01.mdl', 'models/humans/group03m/female_01.mdl',
}

local FEMALE_MEDIC = {
	'models/humans/group03m/female_01.mdl', 'models/humans/group03m/female_02.mdl',
	'models/humans/group03m/female_03.mdl', 'models/humans/group03m/female_04.mdl',
}

bgNPC.cfg.scenic = {
	cheering = {
		place = 'floor', weight = 12,
		group = { min = 2, max = 4, ring = 70 },
		members = { { type = 'citizen', seq = { 'cheer1', 'cheer2' } } },
	},
	food_line = {
		place = 'floor', weight = 10,
		group = { min = 3, max = 5, step = V(-46) },
		members = { { type = 'citizen', seq = { 'LineIdle01', 'LineIdle02', 'LineIdle03', 'LineIdle04' } } },
	},
	plaza = {
		place = 'floor', weight = 10,
		group = { min = 1, max = 3, ring = 80 },
		members = { { type = 'citizen', seq = { 'PlazaIdle', 'PlazaIdle1', 'PlazaIdle2', 'PlazaIdle3', 'PlazaIdle4' } } },
	},
	luggage = {
		place = 'floor', weight = 8,
		group = { min = 1, max = 2, ring = 60 },
		members = { { type = 'citizen', seq = 'd1_t01_Luggage_Idle', weapon = 'weapon_citizensuitcase' } },
	},
	ration = {
		place = 'floor', weight = 8,
		group = { min = 1, max = 2, ring = 60 },
		members = { { type = 'citizen', seq = 'idlepackage', weapon = 'weapon_citizenpackage' } },
	},
	wounded = {
		place = 'floor', weight = 6, ttl = 420,
		members = { { type = 'citizen', seq = { 'd1_town05_Wounded_Idle_1', 'd1_town05_Wounded_Idle_2', 'd1_town05_Winston_Down' } } },
	},
	healing = {
		place = 'floor', weight = 5, ttl = 420,
		members = {
			{ type = 'citizen', seq = 'd1_town05_Wounded_Idle_1' },
			{ type = 'medic', seq = { 'd1_town05_Jacobs_Heal', 'd1_town05_Jacobs_Heal_Entry' }, models = FEMALE_MEDIC,
				pos = V(0, -28), yaw = 90 },
		},
	},
	ground_sit = {
		place = 'floor', weight = 8,
		group = { min = 1, max = 3, ring = 70 },
		members = { { type = 'citizen', seq = 'sit_ground' } },
	},
	tired = {
		place = 'floor', weight = 8,
		group = { min = 1, max = 2, ring = 60 },
		members = { { type = 'citizen', seq = { 'd2_coast03_postbattle_idle01', 'd2_coast03_postbattle_idle02' } } },
	},
	kneeling = {
		place = 'floor', weight = 6,
		members = { { type = 'citizen', seq = 'd1_town05_daniels_kneel_idle' } },
	},
	waving = {
		place = 'floor', weight = 6,
		members = { { type = 'citizen', seq = { 'wave', 'wave_close' } } },
	},
	sky_watch = {
		place = 'sky', weight = 6,
		group = { min = 1, max = 3, ring = 80 },
		members = { { type = 'citizen', weapon = 'weapon_smg1',
			seq = { 'd2_coast03_prebattle_scan_skies', 'd2_coast03_prebattle_scan_skies02', 'd2_coast03_prebattle_scan_skies03' } } },
	},
	cowering = {
		place = 'wall', weight = 7, gap = 18,
		group = { min = 1, max = 2, step = V(0, 50) },
		members = { { type = 'citizen', seq = 'cower_idle' } },
	},
	hiding = {
		place = 'wall', weight = 6, gap = 18,
		members = { { type = 'citizen', seq = 'crouchidlehide' } },
	},
	lean_back = {
		place = 'wall', weight = 9, gap = 14,
		group = { min = 1, max = 3, step = V(0, 70) },
		members = { { type = 'citizen', seq = 'Lean_Back' } },
	},
	lean_side = {
		place = 'wall', weight = 9, gap = 14,
		group = { min = 1, max = 2, step = V(70, 0) },
		members = { { type = 'citizen', seq = 'Lean_Left', yaw = 90 } },
	},
	arrest_wall = {
		place = 'wall', weight = 7, gap = 24, ttl = 420,
		members = {
			{ type = 'citizen', seq = 'spreadwallidle', yaw = 180 },
			{ type = 'police', seq = { 'spreadwall', 'busyidle2' }, pos = V(41), yaw = 180 },
		},
	},
	arrest_ground = {
		place = 'floor', weight = 6, ttl = 420,
		members = {
			{ type = 'citizen', seq = 'arrestidle' },
			{ type = 'police', seq = { 'arrestpreidle', 'busyidle2' }, pos = V(70), yaw = 180 },
		},
	},
	interrogation = {
		place = 'floor', weight = 6, ttl = 420,
		members = {
			{ type = 'citizen', seq = 'arrestpreidle', yaw = 180 },
			{ type = 'police', seq = 'arrestpreidle', pos = V(-47) },
		},
	},
	entrance_block = {
		place = 'door', weight = 7, gap = 44,
		members = { { type = 'police', seq = 'BlockEntry', yaw = 180 } },
	},
	door_knock = {
		place = 'door', weight = 7, gap = 36,
		-- adoorknock reaches along the model's left axis, not its forward axis.
		members = { { type = 'police', seq = 'adoorknock', yaw = -90 } },
	},
	door_brace = {
		place = 'door', weight = 6, gap = 34,
		members = { { type = 'citizen', seq = { 'doorbracer_closed', 'doorbracer_struggle' } } },
	},
	couch_couple = {
		place = 'floor', weight = 5, ttl = 420,
		members = {
			{ type = 'citizen', seq = 'd1_t03_sit_couch_consoling', models = COUPLE_MALE, pos = V(0, -11, 1), yaw = -20 },
			{ type = 'citizen', seq = 'd1_t03_sit_couch', models = COUPLE_FEMALE, pos = V(-3, 12, 1) },
		},
		props = { { model = { 'models/props_c17/FurnitureCouch001a.mdl', 'models/props_interiors/Furniture_Couch01a.mdl' },
			pos = V(-19, -18, 16), solid = false } },
	},
	couch_lying = {
		place = 'floor', weight = 6, ttl = 420,
		members = { { type = 'citizen', seq = 'laycouch1' } },
		props = { { model = 'models/props_c17/FurnitureCouch001a.mdl', pos = V(-2, 11, 16), solid = false } },
	},
	radio_operator = {
		place = 'floor', weight = 5, ttl = 480,
		members = { { type = 'citizen', seq = 'd1_town05_leon_lean_table_idle' } },
		props = {
			{ model = 'models/props_wasteland/controlroom_desk001b.mdl', pos = V(33, 20, 16.7), yaw = 180 },
			{ model = 'models/props_lab/citizenradio.mdl', pos = V(37.5, -8.3, 34), yaw = 190 },
			{ model = 'models/props_c17/tv_monitor01.mdl', pos = V(41, 25, 47), yaw = 180 },
			{ model = 'models/props_lab/harddrive02.mdl', pos = V(41, 43, 43.5), yaw = 165 },
		},
	},
	chair_sitting = {
		place = 'chair', weight = 14, ttl = 480,
		members = { { type = 'citizen', seq = 'Sit_Chair', seat = true } },
	},
}
