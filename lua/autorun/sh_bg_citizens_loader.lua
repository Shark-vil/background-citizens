--[[
	WIKI:
	https://background-npcs.itpony.ru/wik
--]]

hook.Add("PostGamemodeLoaded", "BGN_SlibraryExistsChecker", function()
	if slib ~= nil then return end
	
	if SERVER then
		AddCSLuaFile('bg_citizens_core/errors/sh_slib_error.lua')
	end
	include('bg_citizens_core/errors/sh_slib_error.lua')
end)