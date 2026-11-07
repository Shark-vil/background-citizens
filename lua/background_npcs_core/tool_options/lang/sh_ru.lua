local target_directory = 'background_npcs_core/tool_options/lang/'
if SERVER then
	for _, name in ipairs(file.Find(target_directory .. 'ru/*.lua', 'LUA')) do
		AddCSLuaFile(target_directory .. 'ru/' .. name)
	end
end

if SERVER then return end

local lang = {}

table.Merge(lang, include(target_directory .. 'ru/cl_options.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_actors.lua'))

bgNPC.LANGUAGES['russian'] = lang