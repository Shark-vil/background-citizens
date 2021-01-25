--[[
	WIKI:
	https://background-npcs.itpony.ru/wik
--]]

file.CreateDir('citizens_points')
file.CreateDir('citizens_points_compile')

if SERVER then
	resource.AddFile('materials/background_npcs/vgui/wanted_star.png')
end

bgNPC = {}

-- Do not change -------------
bgNPC.cfg = {}
bgNPC.actors = {}
bgNPC.factors = {}
bgNPC.npcs = {}
bgNPC.fnpcs = {}
bgNPC.points = {}
bgNPC.wanted = {}
bgNPC.killing_statistic = {}
-- ---------------------------

local root_directory = 'bg_citizens_core'

local function p_include(file_path)
	include(file_path)
	MsgN('[Background NPCs] Script load - ' .. file_path)
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

using('modules/extend/net/sh_callback.lua')
using('modules/extend/cvars/sh_global_cvars.lua')

using('config/sh_main.lua')
using('config/sh_npcs.lua')
using('config/states/sh_wanted.lua')
using('config/states/sh_arrest.lua')

if bgNPC.cfg.loadPresets then
	using('map_presets/rp_southside.lua', 'sv')
	using('map_presets/gm_bigcity_improved.lua', 'sv')
	using('map_presets/rp_bangclaw.lua', 'sv')
end

using('cvars/sh_cvars.lua')
using('cvars/sv_cvars.lua')
using('cvars/cl_cvars.lua')

using('global/sv_meta.lua')
using('global/sh_meta.lua')
using('global/sh_net_variables.lua')
using('global/sh_actors_finder.lua')
using('global/sh_actors_register.lua')
using('global/sh_killing_statistic.lua')

using('classes/cl_actor_sync.lua')
using('classes/sh_actor_class.lua')

using('modules/sv_npc_look_at_object.lua')
using('modules/sv_player_look_at_object.lua')
using('modules/sv_static_animation_controller.lua')
using('modules/sv_friend_fixed.lua')
using('modules/npcs/sv_police_helicopter_spawn_rules.lua')
using('modules/npcs/sv_set_citizen_model.lua')
using('modules/npcs/sv_set_gangster_model.lua')
using('modules/darkrp/sv_darkrp_drop_money.lua')
using('modules/darkrp/sv_player_arrest.lua')
using('modules/routes/sh_route_saver.lua')
using('modules/routes/sh_route_loader.lua')
using('modules/routes/cl_compile.lua')
using('modules/spawner/sv_npc_remover.lua')
using('modules/spawner/sv_npc_creator.lua')
using('modules/quest_dialogue/sv_parent_dialogue.lua')
using('modules/states/sv_arrest.lua')
using('modules/states/sv_state_randomize.lua')
using('modules/states/wanted/sh_wanted_class.lua')
using('modules/states/wanted/sv_wanted_actions.lua')
using('modules/states/wanted/cl_wanted_sync.lua')
using('modules/states/wanted/cl_visual_wanted.lua')

using('actions/sv_open_door.lua')
using('actions/sv_police_luggage.lua')
using('actions/sv_damage_reaction.lua')
using('actions/sv_killed_actor.lua')
using('actions/sv_reset_targets.lua')
using('actions/sv_self_damage.lua')
using('actions/sh_player_spawn_sync_actors.lua')

using('states/sv_impingement.lua')
using('states/sv_protection.lua')
using('states/sv_fear.lua')
using('states/sv_stroll.lua')
using('states/sv_calling_police.lua')
using('states/sv_idle.lua')
using('states/sv_arrest.lua')

using('tool_options/cl_bgn_settings_menu.lua')