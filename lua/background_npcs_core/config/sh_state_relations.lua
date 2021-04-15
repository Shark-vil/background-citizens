--[[
	Explanation:
	The states that are in the "danger" category are used to determine the state of danger of the NPC when taking damage.
--]]
bgNPC.cfg.npcs_states = {
	['calmly'] = {
		'idle',
		'walk',
		'dialogue',
		'sit_to_chair',
		'sit_to_chair_2',
		'steal',
		'arrest',
		'retreat'
	},
	['danger'] = {
		'fear',
		'defense',
		'calling_police',
		'impingement',
		'killer',
		'zombie',
		'dyspnea_danger',
		'run_from_danger'
	}
}