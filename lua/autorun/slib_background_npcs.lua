--[[
	The presence of the "Slibrary" is checked here.

	The addon is loaded here:
	lua/slib_autoloader/sh_background_npcs.lua
--]]

hook.Add("PostGamemodeLoaded", "BGN_SlibraryExistsChecker", function()
	if slib ~= nil then return end
	
	if SERVER then
		AddCSLuaFile('background_npcs_core/errors/sh_slib_error.lua')
	end
	include('background_npcs_core/errors/sh_slib_error.lua')
end)