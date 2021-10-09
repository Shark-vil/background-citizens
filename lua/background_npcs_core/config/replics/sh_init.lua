bgNPC.cfg.replics = {}

if SERVER then
	AddCSLuaFile('language/sh_en.lua')
	AddCSLuaFile('language/sh_ru.lua')
end

local full_path_to_language_dir = 'background_npcs_core/config/replics/'
local default_file_path = 'language/sh_' .. GetConVar('bgn_module_replics_language'):GetString() .. '.lua'

if not file.Exists(full_path_to_language_dir .. default_file_path, 'LUA') then
	default_file_path = 'language/sh_' .. GetConVar('cl_language'):GetString() .. '.lua'
end

if not file.Exists(full_path_to_language_dir .. default_file_path, 'LUA') then
	default_file_path = 'language/sh_en.lua'
end

cvars.AddChangeCallback('bgn_module_replics_language', function(_, _, lang)
	if file.Exists(full_path_to_language_dir .. 'language/sh_' .. lang .. '.lua', 'LUA') then
		include('language/sh_' .. lang .. '.lua')
	end
end)

include(default_file_path)