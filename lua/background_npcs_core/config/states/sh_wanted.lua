bgNPC.cfg.wanted = { levels = {}, texture = {}, color = {}, language = {} }

-- Stars to kills ratio
-- After getting a new star, the statistics are updated again!
bgNPC.cfg.wanted.levels = {
	[1] = 5,
	[2] = 5,
	[3] = 10,
	[4] = 10,
	[5] = 15,
}

-- TEXTURE --
bgNPC.cfg.wanted.texture['wanted_star'] = Material('background_npcs/vgui/wanted_star.png')

-- COLOR --
bgNPC.cfg.wanted.color['calling_police_text'] = Color(82, 223, 255)
bgNPC.cfg.wanted.color['calling_police_text_outline'] = Color(0, 0, 0)
bgNPC.cfg.wanted.color['calling_police_halo'] = Color(0, 60, 255)
bgNPC.cfg.wanted.color['wanted_halo'] = Color(240, 34, 34)

-- LANGUAGE --
local text = slib.language({
	['default'] = {
		['wanted_text_s'] = 'YOU ARE WANTED! The search will end in %time% seconds...',
		['wanted_text_m'] = 'YOU ARE WANTED! The search will end in %time% minutes...',
		['calling_police'] = 'Calling police...'
	},
	['russian'] = {
		['wanted_text_s'] = 'ВЫ В РОЗЫСКЕ! Вас перестанут искать через %time% секунд...',
		['wanted_text_m'] = 'ВЫ В РОЗЫСКЕ! Вас перестанут искать через %time% минут...',
		['calling_police'] = 'Звонит в полицию...'
	}
})

bgNPC.cfg.wanted.language['wanted_text_s'] = text['wanted_text_s']
bgNPC.cfg.wanted.language['wanted_text_m'] = text['wanted_text_m']
bgNPC.cfg.wanted.language['calling_police'] = text['calling_police']