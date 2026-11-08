local target_directory = 'background_npcs_core/ui/settings/lang/'
if SERVER then
	for _, name in ipairs(file.Find(target_directory .. 'en/*.lua', 'LUA')) do
		AddCSLuaFile(target_directory .. 'en/' .. name)
	end
end

if SERVER then return end

local lang = {}

table.Merge(lang, include(target_directory .. 'en/cl_options.lua'))

bgNPC.LANGUAGES['english'] = lang