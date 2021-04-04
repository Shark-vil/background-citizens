bgNPC.cfg.wanted = { levels = {}, texture = {}, color = {}, language = {} }

-- Stars to kills ratio
-- After getting a new star, the statistics are updated again!
bgNPC.cfg.wanted.levels = {
	[1] = 10,
	[2] = 10,
	[3] = 15,
	[4] = 20,
	[5] = 25,
}

-- TEXTURE --
bgNPC.cfg.wanted.texture['wanted_star'] = Material('background_npcs/vgui/wanted_star.png')

-- COLOR --
bgNPC.cfg.wanted.color['calling_police_text'] = Color(82, 223, 255)
bgNPC.cfg.wanted.color['calling_police_text_outline'] = Color(0, 0, 0)
bgNPC.cfg.wanted.color['calling_police_halo'] = Color(0, 60, 255)
bgNPC.cfg.wanted.color['wanted_halo'] = Color(240, 34, 34)

-- LANGUAGE --
bgNPC.cfg.wanted.language['wanted_text_s'] = 'YOU ARE WANTED! The search will end in %time% seconds...'
bgNPC.cfg.wanted.language['wanted_text_m'] = 'YOU ARE WANTED! The search will end in %time% minutes...'
bgNPC.cfg.wanted.language['calling_police'] = 'Calling police...'