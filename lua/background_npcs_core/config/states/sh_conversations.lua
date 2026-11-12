--[[
	Conversations of NPCs standing together (systems/dialogue/sv_conversation.lua). Pure data: the voice generator
	(tools/make_voices.py) reads this file too.

	id       the text: bgNPC.cfg.replics['conv_<id>'] in every language file, one phrase per line below
	roles    actor types, one entry per participant (a list = any of these types); 2 or 3 participants
	lines    { speaker role, mood } per phrase. Moods: talk, wave, angry, laugh, scared (an animation)
	final    what happens at the end (none: everyone goes back to their business, and a player standing close
	         and looking at them may interrupt):
	           fight    roles 1 and 2 brawl (fists; police nearby arrest both)
	           attack   role 2 opens fire on role 1
	           flee     role 2 runs from role 1 (police as role 1: give up and get arrested, or get shot)
	           run_off  role 1 runs off somewhere
	chance   relative weight (default 10)
--]]
local CIVILIAN = {'citizen', 'taxi_driver'}
bgNPC.cfg.conversations = {
  {
    id = 'greet',
    roles = {CIVILIAN, CIVILIAN},
    lines = {{1, 'wave'}, {2, 'wave'}, {1}, {2}, {1, 'wave'}}
  },
  {
    id = 'prices',
    roles = {CIVILIAN, CIVILIAN},
    lines = {{1}, {2, 'angry'}, {1}, {2, 'laugh'}}
  },
  {
    id = 'rain',
    roles = {CIVILIAN, CIVILIAN, CIVILIAN},
    lines = {{1}, {2, 'angry'}, {3, 'laugh'}, {2}, {1, 'wave'}}
  },
  {
    id = 'gossip',
    roles = {CIVILIAN, CIVILIAN},
    lines = {{1}, {2}, {1}, {2}, {1, 'laugh'}}
  },
  {
    id = 'lost_dog',
    roles = {CIVILIAN, CIVILIAN},
    lines = {{1, 'wave'}, {2}, {1, 'scared'}, {2, 'wave'}}
  },
  {
    id = 'football',
    roles = {CIVILIAN, CIVILIAN, CIVILIAN},
    lines = {{1}, {2, 'laugh'}, {3, 'angry'}, {2}, {3, 'laugh'}}
  },
  {
    id = 'car_scratch',
    roles = {CIVILIAN, CIVILIAN},
    final = 'fight',
    chance = 5,
    lines = {{1, 'angry'}, {2}, {1, 'angry'}, {2, 'angry'}, {1, 'angry'}}
  },
  {
    id = 'iron',
    roles = {CIVILIAN, CIVILIAN},
    final = 'run_off',
    chance = 5,
    lines = {{1}, {2, 'laugh'}, {1, 'scared'}}
  },
  {
    id = 'police_check',
    roles = {'police', CIVILIAN},
    lines = {{1}, {2}, {1}, {2}, {1}}
  },
  {
    id = 'police_directions',
    roles = {CIVILIAN, 'police'},
    lines = {{1, 'wave'}, {2}, {1, 'wave'}, {2}}
  },
  {
    id = 'police_patrol',
    roles = {'police', 'police', 'police'},
    lines = {{1}, {2}, {3}, {1}}
  },
  {
    id = 'police_patrol_2',
    roles = {'police', 'police'},
    lines = {{1}, {2, 'laugh'}, {1}, {2}}
  },
  {
    id = 'police_gangster',
    roles = {'police', 'gangster'},
    final = 'attack',
    lines = {{1}, {2}, {1, 'angry'}, {2, 'angry'}}
  },
  {
    id = 'police_gangster_calm',
    roles = {'police', 'gangster'},
    lines = {{1, 'angry'}, {2}, {1}}
  },
  {
    id = 'police_thief',
    roles = {'police', 'thief'},
    final = 'flee',
    lines = {{1, 'angry'}, {2, 'scared'}, {1}, {2, 'scared'}}
  },
  {
    id = 'gangster_deal',
    roles = {'gangster', 'gangster'},
    lines = {{1}, {2}, {1, 'angry'}, {2}}
  },
  {
    id = 'gangster_turf',
    roles = {'gangster', 'gangster', 'gangster'},
    lines = {{1, 'angry'}, {2, 'angry'}, {3, 'angry'}, {1}}
  },
  {
    id = 'gangster_extort',
    roles = {'gangster', CIVILIAN},
    final = 'flee',
    lines = {{1, 'laugh'}, {2, 'scared'}, {1, 'angry'}, {2, 'scared'}}
  },
  {
    id = 'gangster_insult',
    roles = {'gangster', CIVILIAN},
    final = 'fight',
    chance = 5,
    lines = {{1, 'angry'}, {2}, {1, 'angry'}, {2, 'angry'}}
  },
  {
    id = 'medic_check',
    roles = {'medic', CIVILIAN},
    lines = {{1}, {2}, {1}, {2, 'wave'}}
  },
  {
    id = 'thief_plan',
    roles = {'thief', 'thief'},
    lines = {{1}, {2}, {1}, {2, 'angry'}}
  },
}
