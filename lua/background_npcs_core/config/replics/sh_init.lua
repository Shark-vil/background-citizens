bgNPC.cfg.replics = {}

local function GetFilePath(name)
	return 'background_npcs_core/config/replics/language/sh_' .. name .. '.lua'
end

-- "auto" follows the game language; unknown languages fall back to English
local function GetLanguagePath()
	local name = GetConVar('bgn_module_replics_language'):GetString()
	if name == 'auto' then
		name = select(2, bgNPC.Util.GetLanguage())
	end
	local path = GetFilePath(name)
	return file.Exists(path, 'LUA') and path or GetFilePath('english')
end

if SERVER then
	AddCSLuaFile( GetFilePath('english') )
	AddCSLuaFile( GetFilePath('russian') )
end

include( GetFilePath('english') )
bgNPC.cfg.replics_language = 'english'

-- Only clients translate: the server keeps the English table, it picks phrase indexes from it.
if CLIENT then
	local function Load()
		local path = GetLanguagePath()
		bgNPC.cfg.replics_language = path:match('sh_(%a+)%.lua$') -- voice clips folder (actor/cl_actor_voice.lua)
		include(path)
	end
	hook.Add('BGN_PostGamemodeLoaded', 'BGN_LoadConfig_Replics_SH_Init', Load)
	cvars.AddChangeCallback('bgn_module_replics_language', Load, 'BGN_Replics')
	cvars.AddChangeCallback('gmod_language', Load, 'BGN_Replics')
	cvars.AddChangeCallback('bgn_cl_ui_language', Load, 'BGN_Replics')
end