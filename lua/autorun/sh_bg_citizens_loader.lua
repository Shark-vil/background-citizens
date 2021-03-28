--[[
	WIKI:
	https://background-npcs.itpony.ru/wik
--]]

hook.Add("PostGamemodeLoaded", "BGN_SlibraryExistsChecker", function()
	if slib ~= nil then return end
	
	if SERVER then
		AddCSLuaFile('background_npcs_core/errors/sh_slib_error.lua')
	end
	include('background_npcs_core/errors/sh_slib_error.lua')
end)