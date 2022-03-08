bgNPC.cfg.replics = {}

local function GetFilePath(name)
	return 'background_npcs_core/config/replics/language/sh_' .. name .. '.lua'
end

local function GetGameLanguage()
	local lnaguage_path = GetFilePath( GetConVar('cl_language'):GetString() )
	if file.Exists(lnaguage_path, 'LUA') then
		return lnaguage_path
	end
end

local function GetCustomLanguage()
	local lnaguage_path = GetFilePath( GetConVar('bgn_module_replics_language'):GetString() )
	if file.Exists(lnaguage_path, 'LUA') then
		return lnaguage_path
	end
end

if SERVER then
	AddCSLuaFile( GetFilePath('english') )
	AddCSLuaFile( GetFilePath('russian') )
end

include( GetFilePath('english') )

if CLIENT then
	hook.Add('BGN_PostGamemodeLoaded', 'BGN_LoadConfig_Replics_SH_Init', function()
		local lnaguage_path = GetGameLanguage()

		if not lnaguage_path then
			lnaguage_path = GetCustomLanguage()
		end

		if lnaguage_path then
			include(lnaguage_path)
		end
	end)
end

cvars.AddChangeCallback('bgn_module_replics_language', function(_, _, lang)
	local lnaguage_path = GetFilePath(lang)

	if not file.Exists(lnaguage_path, 'LUA') then return end
	include(lnaguage_path)
end)