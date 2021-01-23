--[[
    Template variables
--]]

local cfg_texture = {}
local cfg_color = {}
local cfg_lang = {}

--[[
    Config setting
--]]

-- TEXTURE --
cfg_texture['wanted_star'] = Material('background_npcs/vgui/wanted_star.png')

-- COLOR --
cfg_color['calling_police_text'] = Color(82, 223, 255)
cfg_color['calling_police_text_outline'] = Color(0, 0, 0)
cfg_color['calling_police_halo'] = Color(0, 60, 255)
cfg_color['wanted_halo'] = Color(240, 34, 34)

-- LANGUAGE --
cfg_lang['wanted_text_s'] = 'YOU ARE WANTED! The search will end in %time% seconds...'
cfg_lang['wanted_text_m'] = 'YOU ARE WANTED! The search will end in %time% minutes...'
cfg_lang['calling_police'] = 'Calling police...'

--[[
    Assigning settings
--]]

bgNPC.cfg.wanted = {}
bgNPC.cfg.wanted.texture = cfg_texture
bgNPC.cfg.wanted.color = cfg_color
bgNPC.cfg.wanted.language = cfg_lang