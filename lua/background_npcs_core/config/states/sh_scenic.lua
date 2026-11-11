--[[
	Scenic NPCs: staged scenes that appear on the map by themselves (systems/scenic/).
	A scene is data; a spot finder looks for a place that fits it, so nothing here depends on the map.

	Scene fields:
		place   where the scene can stand (finders: systems/scenic/sv_scenic_finders.lua)
		          floor  flat floor          sky   flat floor under the open sky
		          wall   flat wall, the actors stand with their backs to it (yaw 180 - face it)
		          door   a closed door, the actors stand in front of it facing it (yaw 180 - turn away)
		          chair  a chair prop of bgNPC.cfg.sit_chairs or a custom seat
		          ledge  a wide flat lip with a knee-height drop
		weight  relative chance (default 10), 0 = manual spawn only
		indoors require a nearby solid ceiling, walls in four directions and room for decor
		atomic  cancel the whole scene if any member cannot start its pose
		gap     distance to the wall or to the door (default 22 / 40)
		ttl     seconds before the unseen scene is cleaned up (default 600)
		group   the first member is repeated min..max times: step = Vector shift of every next copy
		        (forward, right, up), ring = radius of a loose cluster
		members one actor each:
		          type    actor type of the config (any body: an NPC and a NextBot play the same sequences)
		          seq     sequence or list; one supported sequence is picked at random and looped
		          pos     Vector(forward, right, up) from the scene spot, yaw - turn from the spot angle
		          seq_offsets local Vector per lowercase sequence name, applied after floor placement
		          weapon  weapon equipped for the pose
		          carry   ration / suitcase / newspaper walking preview instead of a static pose
		          seat    placed on the chair of the spot (place = 'chair')
		props   decor created with the scene: model, pos, yaw, solid (default true)
--]]

local function V(forward, right, up)
	return Vector(forward or 0, right or 0, up or 0)
end

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
		members = { { type = 'citizen', seq = { 'plazastand1', 'plazastand2', 'plazastand3', 'plazastand4' } } },
	},
	luggage = {
		place = 'floor', weight = 0,
		members = { { type = 'citizen', carry = 'suitcase' } },
	},
	ration = {
		place = 'floor', weight = 0,
		members = { { type = 'citizen', carry = 'ration' } },
	},
	newspaper = {
		place = 'floor', weight = 0,
		members = { { type = 'citizen', carry = 'newspaper' } },
	},
	wounded = {
		place = 'floor', weight = 6, ttl = 420,
		members = { { type = 'citizen', seq = { 'd1_town05_Wounded_Idle_1', 'd1_town05_Wounded_Idle_2', 'd1_town05_Winston_Down' } } },
	},
	healing = {
		place = 'floor', weight = 5, ttl = 420,
		members = {
			{ type = 'citizen', seq = 'd1_town05_Wounded_Idle_1' },
			{ type = 'medic', seq = { 'd1_town05_Jacobs_Heal', 'd1_town05_Jacobs_Heal_Entry' },
				pos = V(0, -28), yaw = 90 },
		},
	},
	ground_sit = {
		place = 'floor', weight = 8,
		members = { { type = 'citizen', seq = { 'sit_ground', 'sitcouchfeet1', 'sitcouchknees1' },
			seq_offsets = { sitcouchfeet1 = V(16, 0, -16), sitcouchknees1 = V(16, 0, -14) } } },
	},
	tired = {
		place = 'floor', weight = 8,
		members = { { type = 'citizen', seq = { 'd2_coast03_postbattle_idle02', 'LineIdle01', 'idle_subtle' } } },
	},
	tired_wall = {
		place = 'wall', weight = 5, gap = 18,
		members = { { type = 'citizen', seq = 'd2_coast03_postbattle_idle01', yaw = 180 } },
	},
	ledge_sitting = {
		place = 'ledge', weight = 8,
		members = { { type = 'citizen', seq = { 'd1_t02_Plaza_Sit01_Idle', 'd1_t02_Plaza_Sit02' } } },
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
		place = 'sky', weight = 0,
		group = { min = 1, max = 3, ring = 80 },
		members = { { type = 'citizen', weapon = 'weapon_smg1',
			seq = { 'd2_coast03_prebattle_scan_skies', 'd2_coast03_prebattle_scan_skies02', 'd2_coast03_prebattle_scan_skies03' } } },
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
			{ type = 'citizen', seq = 'spreadwallidle', yaw = 180, seq_offsets = { spreadwallidle = V(28) } },
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
			{ type = 'citizen', seq = { 'arrestcurious', 'scaredidle', 'idle_subtle' }, yaw = 180 },
			{ type = 'police', seq = { 'harassfront1', 'harassfront2' }, pos = V(-60) },
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
		place = 'door', weight = 0, gap = 16,
		members = { { type = 'citizen', seq = { 'doorbracer_struggle', 'doorbracer_closed' },
			seq_offsets = { doorbracer_struggle = V(5), doorbracer_closed = V(5) } } },
	},
	couch_couple = {
		place = 'floor', weight = 4, ttl = 420, indoors = true, atomic = true,
		members = {
			{ type = 'citizen', seq = { 'd1_t03_sit_couch_consoling', 'd1_t03_sit_couch' }, pos = V(-5, -32, -5) },
			{ type = 'citizen', seq = { 'd1_t03_sit_couch', 'sitcouch1' }, pos = V(-5, -1, -5),
				seq_offsets = { sitcouch1 = V(15) } },
		},
		props = { { model = 'models/props_c17/FurnitureCouch001a.mdl',
			pos = V(-19, -18, 16), solid = false } },
	},
	couch_lying = {
		place = 'floor', weight = 4, ttl = 420, indoors = true,
		members = { { type = 'citizen', seq = 'laycouch1' } },
		props = { { model = 'models/props_c17/FurnitureCouch001a.mdl', pos = V(-2, 11, 16), solid = false } },
	},
	radio_operator = {
		place = 'floor', weight = 4, ttl = 480, indoors = true,
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

local names = {
	tired_wall = { 'Tired citizen at a wall', 'Уставший у стены' },
	ledge_sitting = { 'Sitting on a ledge', 'Сидящий на уступе' },
	cheering = { 'Cheering', 'Радующиеся жители' }, food_line = { 'Food queue', 'Очередь за едой' },
	plaza = { 'Standing citizen', 'Стоящий житель' }, luggage = { 'Citizen with a suitcase / briefcase', 'Житель с чемоданом / кейсом' },
	newspaper = { 'Citizen with a newspaper', 'Житель с газетой' },
	ration = { 'Citizen with a ration box', 'Житель с пайком' }, wounded = { 'Wounded citizen', 'Раненый житель' },
	healing = { 'Medic helping a citizen', 'Помощь медика' }, ground_sit = { 'Sitting on the ground', 'Сидящий на земле' },
	tired = { 'Tired citizen', 'Уставший житель' }, kneeling = { 'Kneeling', 'Житель на коленях' },
	waving = { 'Waving', 'Житель машет рукой' }, sky_watch = { 'Watching the sky', 'Наблюдение за небом' },
	hiding = { 'Hiding at a wall', 'Прячущийся у стены' },
	lean_back = { 'Leaning back', 'Опирающиеся спиной на стену' }, lean_side = { 'Leaning sideways', 'Опирающиеся боком на стену' },
	arrest_wall = { 'Wall search', 'Обыск у стены' }, arrest_ground = { 'Ground arrest', 'Задержанный на земле' },
	interrogation = { 'Interrogation', 'Допрос' }, entrance_block = { 'Guarding an entrance', 'Полицейский у входа' },
	door_knock = { 'Knocking on a door', 'Стук в дверь' }, door_brace = { 'Door brace pose', 'Поза удерживания двери' },
	couch_couple = { 'Couple on a couch', 'Пара на диване' }, couch_lying = { 'Lying on a couch', 'Лежащий на диване' },
	radio_operator = { 'Radio operator', 'Радист' }, chair_sitting = { 'Sitting on a chair', 'Сидящий на стуле' },
}
for id, scene in pairs(bgNPC.cfg.scenic) do
	local name = names[id]
	if name then scene.name = { default = name[1], russian = name[2] } end
end
