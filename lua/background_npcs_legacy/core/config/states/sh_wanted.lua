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
-- bgNPC.cfg.wanted.color['calling_police_text'] = Color(82, 223, 255)
-- bgNPC.cfg.wanted.color['calling_police_text_outline'] = Color(0, 0, 0)
-- bgNPC.cfg.wanted.color['calling_police_halo'] = Color(0, 60, 255)
-- bgNPC.cfg.wanted.color['wanted_halo'] = Color(240, 34, 34)

-- COLOR --
do
	local function ConVarColorInit(convar_name, r, g, b)
		bgNPC.cfg.wanted.color[convar_name] = Color(r, g, b)

		scvar.Register('bgn_wanted_color_' .. convar_name .. '_r', r, FCVAR_ARCHIVE, '').Access(DefaultAccess)
		scvar.Register('bgn_wanted_color_' .. convar_name .. '_g', g, FCVAR_ARCHIVE, '').Access(DefaultAccess)
		scvar.Register('bgn_wanted_color_' .. convar_name .. '_b', b, FCVAR_ARCHIVE, '').Access(DefaultAccess)

		do
			local last_r = GetConVar('bgn_wanted_color_' .. convar_name .. '_r'):GetInt()
			local last_g = GetConVar('bgn_wanted_color_' .. convar_name .. '_g'):GetInt()
			local last_b = GetConVar('bgn_wanted_color_' .. convar_name .. '_b'):GetInt()
			bgNPC.cfg.wanted.color[convar_name] = Color(last_r, last_g, last_b)
		end

		slib.GlobalCvarAddChangeCallback('bgn_wanted_color_' .. convar_name .. '_r', function(_, _, newValue)
			local color = bgNPC.cfg.wanted.color[convar_name]
			color.r = tonumber(newValue)
			bgNPC.cfg.wanted.color[convar_name] = color
		end)

		slib.GlobalCvarAddChangeCallback('bgn_wanted_color_' .. convar_name .. '_g', function(_, _, newValue)
			local color = bgNPC.cfg.wanted.color[convar_name]
			color.g = tonumber(newValue)
			bgNPC.cfg.wanted.color[convar_name] = color
		end)

		slib.GlobalCvarAddChangeCallback('bgn_wanted_color_' .. convar_name .. '_b', function(_, _, newValue)
			local color = bgNPC.cfg.wanted.color[convar_name]
			color.b = tonumber(newValue)
			bgNPC.cfg.wanted.color[convar_name] = color
		end)
	end

	ConVarColorInit('calling_police_text', 82, 223, 255)
	-- ConVarColorInit('calling_police_text_outline', 0, 0, 0)
	bgNPC.cfg.wanted.color['calling_police_text_outline'] = Color(0, 0, 0)
	ConVarColorInit('calling_police_halo', 0, 60, 255)
	ConVarColorInit('wanted_halo', 240, 34, 34)
end

-- LANGUAGE --
local text = slib.language({
	['default'] = {
		['wanted_text_s'] = 'YOU ARE WANTED! The search will end in %time% sec.',
		['wanted_text_m'] = 'YOU ARE WANTED! The search will end in %time% min.',
		['calling_police'] = 'Calling police...'
	},
	['russian'] = {
		['wanted_text_s'] = 'ВЫ В РОЗЫСКЕ! Вас перестанут искать через %time% сек.',
		['wanted_text_m'] = 'ВЫ В РОЗЫСКЕ! Вас перестанут искать через %time% мин.',
		['calling_police'] = 'Звонит в полицию...'
	}
})

bgNPC.cfg.wanted.language['wanted_text_s'] = text['wanted_text_s']
bgNPC.cfg.wanted.language['wanted_text_m'] = text['wanted_text_m']
bgNPC.cfg.wanted.language['calling_police'] = text['calling_police']