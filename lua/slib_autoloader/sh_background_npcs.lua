--[[
	WIKI:
	https://background-npcs.itpony.ru/wik
--]]

file.CreateDir('background_npcs')
file.CreateDir('background_npcs/nodes')
file.CreateDir('background_npcs/compile')

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

local root_directory = 'background_npcs_core'
local script = slib.CreateIncluder(root_directory, '[Background NPCs] Script load - {file}')

script:using('config/sh_main.lua')
script:using('config/sh_npcs.lua')
script:using('config/sh_shot_sound.lua')
script:using('config/sh_player.lua')
script:using('config/sh_darkrp.lua')

hook.Add("PostGamemodeLoaded", "BGN_LoadAllowTeamsFromTeamParentModule", function()
	include(root_directory .. '/config/sh_player.lua')
	hook.Remove("PostGamemodeLoaded", "BGN_LoadAllowTeamsFromTeamParentModule")
end)

script:using('config/states/sh_wanted.lua')
script:using('config/states/sh_arrest.lua')
script:using('config/states/sh_dialogue.lua')
script:using('config/states/sh_sit_chair.lua')

script:using('cvars/sh_cvars.lua')
script:using('cvars/sv_cvars.lua')
script:using('cvars/cl_cvars.lua')

script:using('global/sv_meta.lua')
script:using('global/sh_meta.lua')
script:using('global/sh_net_variables.lua')
script:using('global/sh_actors_finder.lua')
script:using('global/sh_actors_register.lua')
script:using('global/sh_killing_statistic.lua')
script:using('global/sh_wanted_killing_statistic.lua')
script:using('global/sh_states.lua')
script:using('global/sh_find_path_service.lua')

script:using('classes/cl_actor_sync.lua')
script:using('classes/sh_actor_class.lua')
script:using('classes/sh_node_class.lua')

script:using('modules/cl_updatepage.lua')
script:using('modules/cl_render_optimization.lua')
script:using('modules/sv_run_logic_optimization.lua')
script:using('modules/debug/cl_render_target_path.lua')
script:using('modules/sv_npc_look_at_object.lua')
script:using('modules/sv_player_look_at_object.lua')
script:using('modules/sv_static_animation_controller.lua')
script:using('modules/sv_friend_fixed.lua')
script:using('modules/sv_first_attacker_found.lua')
script:using('modules/sv_autoregen.lua')
script:using('modules/sv_zombie_mode.lua')
script:using('modules/sv_dropmoney.lua')
script:using('modules/sv_n2money_drop.lua')
script:using('modules/npcs/sv_police_helicopter_spawn_rules.lua')
script:using('modules/npcs/sv_set_citizen_model.lua')
script:using('modules/npcs/sv_set_gangster_model.lua')
script:using('modules/npcs/sv_set_custom_health.lua')
script:using('modules/npcs/sv_police_voice.lua')
script:using('modules/npcs/sv_random_voice.lua')
script:using('modules/npcs/sv_bio_annihilation_two.lua')
-- script:using('modules/player/sv_sync_npcs_by_pvs.lua')
script:using('modules/player/sv_team_parent.lua')
script:using('modules/darkrp/sv_darkrp_drop_money.lua')
script:using('modules/darkrp/sv_player_arrest.lua')
script:using('modules/darkrp/sv_remove_wanted_if_arrest.lua')
script:using('modules/darkrp/sv_change_team_wanted.lua')
script:using('modules/darkrp/sv_disable_door_open.lua')
script:using('modules/sandbox/sv_arrest.lua')
script:using('modules/routes/sh_route_saver.lua')
script:using('modules/routes/sh_route_loader.lua')
script:using('modules/routes/cl_compile.lua')
script:using('modules/routes/sv_oldroute_convert.lua')
script:using('modules/spawner/sv_npc_remover.lua')
script:using('modules/spawner/sv_npc_creator.lua')
script:using('modules/spawner/sv_dv_spawner.lua')
script:using('modules/quest_dialogue/sv_parent_dialogue.lua')
script:using('modules/states/sv_arrest.lua')
script:using('modules/states/sv_state_randomize.lua')
script:using('modules/states/sv_dialogue.lua')
script:using('modules/states/sv_walk.lua')
script:using('modules/states/wanted/sh_wanted_class.lua')
script:using('modules/states/wanted/sv_wanted_actions.lua')
script:using('modules/states/wanted/cl_wanted_sync.lua')
script:using('modules/states/wanted/cl_visual_wanted.lua')
script:using('modules/states/steal_money/sv_darkrp.lua')
script:using('modules/states/steal_money/sv_n2money.lua')
script:using('modules/ambient/cl_ambient_sound.lua')
script:using('modules/dv/sv_fix_autoload_routes.lua')

script:using('actions/sv_open_door.lua')
script:using('actions/sv_police_luggage.lua')
script:using('actions/sv_damage_reaction.lua')
script:using('actions/sv_killed_actor.lua')
script:using('actions/sv_reset_targets.lua')
script:using('actions/sv_self_damage.lua')
script:using('actions/sh_player_spawn_sync_actors.lua')
script:using('actions/sv_reaction_to_a_shot.lua')
script:using('actions/sv_movement_service.lua')
script:using('actions/sv_enemy_controller.lua')

script:using('states/sv_impingement.lua')
script:using('states/sv_protection.lua')
script:using('states/sv_fear.lua')
script:using('states/sv_walk.lua')
script:using('states/sv_calling_police.lua')
script:using('states/sv_idle.lua')
script:using('states/sv_arrest.lua')
script:using('states/sv_dialogue.lua')
script:using('states/sv_sit_to_chair.lua')
script:using('states/sv_retreat.lua')
script:using('states/sv_dv_vehicle_drive.lua')
script:using('states/sv_steal.lua')
script:using('states/sv_zombie.lua')
script:using('states/sv_killer.lua')

script:using('tool_options/cl_bgn_settings_menu.lua')
script:using('tool_options/cl_lang.lua')
script:using('tool_options/cl_general_settings.lua')
script:using('tool_options/cl_spawn_settings.lua')
script:using('tool_options/cl_state_settings.lua')
script:using('tool_options/cl_active_npc_group_settings.lua')
script:using('tool_options/cl_optimization_settings.lua')
script:using('tool_options/cl_client_settings.lua')
script:using('tool_options/cl_workshop_settings.lua')

-- To connect scripts that depend on the framework
slib.usingDirectory(root_directory .. '/custom_modules',
	'[Background NPCs | Custom modules] Script load - {file}')

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