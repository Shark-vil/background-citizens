--[[
	WIKI:
	https://background-npcs.itpony.ru/wik
--]]

file.CreateDir('citizens_points')
file.CreateDir('citizens_points_compile')

if SERVER then
	resource.AddWorkshop(2341497926)
end

bgNPC = {}
bgNPC.VERSION = "1.4.4"

-- Do not change -------------
bgNPC.cfg = {}
bgNPC.actors = {}
bgNPC.factors = {}
bgNPC.npcs = {}
bgNPC.fnpcs = {}
bgNPC.points = {}
bgNPC.wanted = {}
bgNPC.killing_statistic = {}
bgNPC.wanted_killing_statistic = {}
bgNPC.respawn_actors_delay = {}
bgNPC.NavmeshIsLoaded = false
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

if slib == nil then
	using('errors/sh_slib_error.lua')
	return
end

using('config/sh_main.lua')
using('config/sh_npcs.lua')
using('config/sh_shot_sound.lua')
using('config/sh_player.lua')
using('config/sh_darkrp.lua')

hook.Add("PostGamemodeLoaded", "BGN_LoadAllowTeamsFromTeamParentModule", function()
	include(root_directory .. '/config/sh_player.lua')
	hook.Remove("PostGamemodeLoaded", "BGN_LoadAllowTeamsFromTeamParentModule")
end)

using('config/states/sh_wanted.lua')
using('config/states/sh_arrest.lua')
using('config/states/sh_dialogue.lua')
using('config/states/sh_sit_chair.lua')

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
using('global/sh_wanted_killing_statistic.lua')
using('global/sh_states.lua')
using('global/sh_find_path_service.lua')

using('classes/cl_actor_sync.lua')
using('classes/sh_actor_class.lua')
using('classes/sh_node_class.lua')

using('modules/cl_updatepage.lua')
using('modules/cl_render_optimization.lua')
using('modules/sv_run_logic_optimization.lua')
using('modules/debug/cl_render_target_path.lua')
using('modules/sv_npc_look_at_object.lua')
using('modules/sv_player_look_at_object.lua')
using('modules/sv_static_animation_controller.lua')
using('modules/sv_friend_fixed.lua')
using('modules/sv_first_attacker_found.lua')
using('modules/sv_autoregen.lua')
using('modules/npcs/sv_police_helicopter_spawn_rules.lua')
using('modules/npcs/sv_set_citizen_model.lua')
using('modules/npcs/sv_set_gangster_model.lua')
using('modules/npcs/sv_set_custom_health.lua')
using('modules/npcs/sv_police_voice.lua')
using('modules/npcs/sv_random_voice.lua')
-- using('modules/player/sv_sync_npcs_by_pvs.lua')
using('modules/player/sv_team_parent.lua')
using('modules/darkrp/sv_darkrp_drop_money.lua')
using('modules/darkrp/sv_player_arrest.lua')
using('modules/darkrp/sv_remove_wanted_if_arrest.lua')
using('modules/darkrp/sv_change_team_wanted.lua')
using('modules/darkrp/sv_disable_door_open.lua')
using('modules/sandbox/sv_arrest.lua')
using('modules/routes/sh_route_saver.lua')
using('modules/routes/sh_route_loader.lua')
using('modules/routes/cl_compile.lua')
using('modules/routes/sv_oldroute_convert.lua')
using('modules/spawner/sv_npc_remover.lua')
using('modules/spawner/sv_npc_creator.lua')
using('modules/quest_dialogue/sv_parent_dialogue.lua')
using('modules/states/sv_arrest.lua')
using('modules/states/sv_state_randomize.lua')
using('modules/states/sv_dialogue.lua')
using('modules/states/sv_walk.lua')
using('modules/states/wanted/sh_wanted_class.lua')
using('modules/states/wanted/sv_wanted_actions.lua')
using('modules/states/wanted/cl_wanted_sync.lua')
using('modules/states/wanted/cl_visual_wanted.lua')
using('modules/ambient/cl_ambient_sound.lua')
using('modules/dv/sv_fix_autoload_routes.lua')

using('actions/sv_open_door.lua')
using('actions/sv_police_luggage.lua')
using('actions/sv_damage_reaction.lua')
using('actions/sv_killed_actor.lua')
using('actions/sv_reset_targets.lua')
using('actions/sv_self_damage.lua')
using('actions/sh_player_spawn_sync_actors.lua')
using('actions/sv_reaction_to_a_shot.lua')
using('actions/sv_movement_service.lua')

using('states/sv_impingement.lua')
using('states/sv_protection.lua')
using('states/sv_fear.lua')
-- using('states/sv_stroll.lua')
using('states/sv_walk.lua')
using('states/sv_calling_police.lua')
using('states/sv_idle.lua')
using('states/sv_arrest.lua')
using('states/sv_dialogue.lua')
using('states/sv_sit_to_chair.lua')
using('states/sv_retreat.lua')
using('states/sv_dv_vehicle_drive.lua')
using('states/sv_steal.lua')

using('tool_options/cl_bgn_settings_menu.lua')
using('tool_options/cl_lang.lua')
using('tool_options/cl_general_settings.lua')
using('tool_options/cl_spawn_settings.lua')
using('tool_options/cl_state_settings.lua')
using('tool_options/cl_active_npc_group_settings.lua')
using('tool_options/cl_optimization_settings.lua')
using('tool_options/cl_client_settings.lua')
using('tool_options/cl_workshop_settings.lua')

if CLIENT then
	snet.RegisterValidator('actor', function(ply, uid, ent)
		return bgNPC:GetActor(ent) ~= nil
	end)

	hook.Add('SlibPlayerFirstSpawn', 'BGN_CheckAddonVersion', function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		
		timer.Simple(3, function()
			http.Fetch('https://raw.githubusercontent.com/Shark-vil/background-citizens/master/version.txt',
				function(github_version, length, headers, code)
					if code ~= 200 then
						bgNPC:Log('Failed to check the actual version: error code\n' .. tostring(code), 'Version Checker')
						return
					end

					local v_github = tonumber(string.Replace(github_version, '.', ''))
					local v_addon = tonumber(string.Replace(bgNPC.VERSION, '.', ''))

					local ru_lang = {
						msg_outdated = "Вы используете устаревшую версию \"Background NPCs\" :(\n",
						msg_latest = "Вы используете последнюю версию \"Background NPCs\" :)\n",
						msg_dev = "Вы используете версию для разработчиков \"Background NPCs\" :o\n",
						actual_version = "Актуальная версия - " .. github_version .. " : Ваша версия - " .. bgNPC.VERSION .. "\n",
						update_page_1 = "Используйте консольную команду \"",
						update_page_2 = "\" чтобы посмотреть информацию о последнем выпуске.\n",
						command  = "bgn_updateinfo"
					}

					local en_lang = {
						msg_outdated = "You are using an outdated version of \"Background NPCs\" :(\n",
						msg_latest = "You are using the latest version of \"Background NPCs\" :)\n",
						msg_dev = "You are using the dev version of \"Background NPCs\" :o\n",
						actual_version = "Actual version - " .. github_version .. " : Your version - " .. bgNPC.VERSION .. "\n",
						update_page_1 = "Use the console command \"",
						update_page_2 = "\" to view information about the latest release.\n",
						command  = "bgn_updateinfo"
					}

					local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
					local text_color_info = Color(61, 206, 217)
					local text_command_color = Color(227, 209, 11)
					local text_version_color = Color(237, 153, 43)

					if v_addon < v_github then

						local text_color = Color(255, 196, 0)
						chat.AddText(Color(255, 0, 0), '[ADMIN] ',
							text_color, lang.msg_outdated, text_version_color, lang.actual_version, 
							text_color_info, lang.update_page_1,
							text_command_color, lang.command, text_color_info, lang.update_page_2)

					elseif v_addon == v_github then

						local text_color = Color(30, 255, 0)
						chat.AddText(Color(255, 0, 0), '[ADMIN] ',
							text_color, lang.msg_latest, text_version_color, lang.actual_version, 
							text_color_info, lang.update_page_1,
							text_command_color, lang.command, text_color_info, lang.update_page_2)

					elseif v_addon > v_github then

						local text_color = Color(30, 255, 0)
						chat.AddText(Color(255, 0, 0), '[ADMIN] ',
							text_color, lang.msg_dev, text_version_color, lang.actual_version, 
							text_color_info, lang.update_page_1,
							text_command_color, lang.command, text_color_info, lang.update_page_2)

					end
				end,
				function(message)
					MsgN('[Background NPCs] Failed to check the actual version:\n' .. message)
				end
			)
		end)
	end)
end