file.CreateDir('citizens_points')
file.CreateDir('citizens_points_compile')

bgCitizens = {}
bgCitizens.actors = {} -- Do not change
bgCitizens.factors = {} -- Do not change
bgCitizens.npcs = {} -- Do not change
bgCitizens.fnpcs = {} -- Do not change
bgCitizens.points = {} -- Do not change
bgCitizens.wanted = {} -- Do not change

local root_directory = 'bg_citizens_core'

local function p_include(file_path)
    include(file_path)
    MsgN('[Background NPCs] script load - ' .. file_path)
end

local function using(local_file_path, network_type, not_root_directory)
    local file_path = local_file_path

    if not not_root_directory then
        file_path = root_directory .. '/' .. local_file_path
    end

    network_type = network_type or string.sub(string.GetFileFromFilename(local_file_path), 1, 2)
    network_type = string.lower(network_type)

    if network_type == 'cl' or network_type == 'sh' then
        if SERVER then AddCSLuaFile(file_path) end
        if CLIENT and network_type == 'cl' then
            p_include(file_path)
        elseif network_type == 'sh' then
            p_include(file_path)
        end
    elseif network_type == 'sv' and SERVER then
        p_include(file_path)
    end
end

using('sv_cvars.lua')
using('sh_config.lua')

if bgCitizens.loadPresets then
    using('map_presets/rp_southside.lua', 'sv')
    using('map_presets/gm_bigcity_improved.lua', 'sv')
end

using('global/sv_meta.lua')
using('global/sh_meta.lua')

using('classes/sh_bg_npc_class.lua')

using('modules/net/sh_callback.lua')
using('modules/sv_npc_look_at_object.lua')
using('modules/sv_player_look_at_object.lua')
using('modules/sv_custom_default_models.lua')
using('modules/sv_darkrp_drop_money.lua')
using('modules/sv_static_animation_controller.lua')
using('modules/routes/sh_route_saver.lua')
using('modules/routes/sh_route_loader.lua')
using('modules/routes/cl_compile.lua')
using('modules/spawner/sv_npc_remover.lua')
using('modules/spawner/sv_npc_creator.lua')

using('actions/sv_open_door.lua')
using('actions/sv_attacked.lua')
using('actions/sv_police_luggage.lua')

using('states/sv_impingement.lua')
using('states/sv_protection.lua')
using('states/sv_fear.lua')
using('states/sv_stroll.lua')
using('states/sh_calling_police.lua')
using('states/sv_idle.lua')