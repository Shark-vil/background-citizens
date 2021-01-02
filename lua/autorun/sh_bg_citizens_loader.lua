bgCitizens = {}
bgCitizens.npcs = {} -- Do not change
bgCitizens.fnpcs = {} -- Do not change
bgCitizens.points = {} -- Do not change

local root_directory = 'bg_citizens_core'

local function _AddCSLuaFile(filename)
    AddCSLuaFile(root_directory .. '/' .. filename)
end

local function _include(filename)
    include(root_directory .. '/' .. filename)
end

file.CreateDir('citizens_points')
file.CreateDir('citizens_points_compile')

if SERVER then
    _AddCSLuaFile('sh_config.lua')
    _AddCSLuaFile('global/sh_meta.lua')
    _AddCSLuaFile('classes/sh_bg_npc_class.lua')
    _AddCSLuaFile('sh_route_saver.lua')
    _AddCSLuaFile('sh_points_loader.lua')
    _AddCSLuaFile('cl_compile.lua')
    _include('sv_cvars.lua')
    _include('sh_config.lua')

    if bgCitizens.loadPresets then
        _include('map_presets/rp_southside.lua')
        _include('map_presets/gm_bigcity_improved.lua')
    end

    _include('global/sv_meta.lua')
    _include('global/sh_meta.lua')
    _include('classes/sh_bg_npc_class.lua')
    _include('sh_route_saver.lua')
    _include('sh_points_loader.lua')
    _include('sv_npc_remover.lua')
    _include('sv_npc_creator.lua')

    _include('actions/sv_open_door.lua')
    _include('actions/sv_attacked.lua')

    _include('states/sv_impingement.lua')
    _include('states/sv_protection.lua')
    _include('states/sv_fear.lua')
    _include('states/sv_stroll.lua')
else
    _include('sh_config.lua')
    _include('global/sh_meta.lua')
    _include('classes/sh_bg_npc_class.lua')
    _include('sh_route_saver.lua')
    _include('sh_points_loader.lua')
    _include('cl_compile.lua')
end