--[[
	WIKI:
	https://background-npcs.itpony.ru/wik
--]]

file.CreateDir('background_npcs')
file.CreateDir('citizens_points')
file.CreateDir('background_npcs/nodes')
file.CreateDir('background_npcs/seats')
file.CreateDir('background_npcs/compile')

if SERVER then
	resource.AddWorkshop(2341497926)
end

bgNPC = {}
bgNPC.VERSION = '1.7.1'

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
bgNPC.DVCars = {}
bgNPC.state_actions = {}
bgNPC.state_actions_groups = {}
-- ---------------------------

local root_directory = 'background_npcs_core'
local script = slib.CreateIncluder(root_directory, '[Background NPCs] Script load - {file}')

script:using('config/sh_main.lua')
script:using('config/replics/sh_init.lua')
script:using('config/sh_names.lua')
script:using('config/sh_npcs.lua')
script:using('config/sh_shot_sound.lua')
script:using('config/sh_player.lua')
script:using('config/gamemodes/sh_darkrp.lua')
script:using('config/sh_ambient.lua')

script:using('config/states/sh_wanted.lua')
script:using('config/states/sh_arrest.lua')
script:using('config/states/sh_dialogue.lua')
script:using('config/states/sh_sit_chair.lua')

slib.usingDirectory(root_directory .. '/custom_modules/config',
	'[Background NPCs | Custom modules] Script load - {file}')

script:using('cvars/sh_cvars.lua')
script:using('cvars/sv_cvars.lua')
script:using('cvars/cl_cvars.lua')

script:using('commands/sh_cmd_config.lua')
script:using('commands/sh_cmd_autogenerator.lua')

slib.usingDirectory(root_directory .. '/custom_modules/preload',
	'[Background NPCs | Custom modules] Script load - {file}')

script:using('classes/actor/sh_actor_base.lua', true)
script:using('classes/actor/cl_actor_text_say.lua')
script:using('classes/actor/sh_actor_class.lua')
script:using('classes/sh_node_class.lua')
script:using('classes/sh_seat_class.lua')
script:using('classes/sh_dv_class.lua')

script:using('global/sv_meta.lua')
script:using('global/sh_meta.lua')
script:using('global/sv_spawner.lua')
script:using('global/sh_actors_finder.lua')
script:using('global/sh_actors_register.lua')
script:using('global/sh_killing_statistic.lua')
script:using('global/sh_wanted_killing_statistic.lua')
script:using('global/sh_states.lua')
script:using('global/sh_find_path_service.lua')
script:using('global/sv_pre_spawn_cache.lua')

script:using('modules/cl_updatepage.lua')
script:using('modules/cl_render_optimization.lua')
script:using('modules/sv_run_logic_optimization.lua')
script:using('modules/debug/cl_render_target_path.lua')
script:using('modules/debug/sv_movement_render.lua')
script:using('modules/debug/cl_movement_render.lua')
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
script:using('modules/player/sv_team_parent.lua')
script:using('modules/darkrp/sv_darkrp_drop_money.lua')
script:using('modules/darkrp/sv_remove_wanted_if_arrest.lua')
script:using('modules/darkrp/sv_change_team_wanted.lua')
script:using('modules/darkrp/sv_disable_door_open.lua')
script:using('modules/arrest/sv_police_system.lua')
script:using('modules/arrest/sv_darkrp_arrest.lua')
script:using('modules/routes/sh_route_saver.lua')
script:using('modules/routes/sh_route_loader.lua')
script:using('modules/routes/compile/sv_compile.lua')
script:using('modules/routes/compile/cl_compile.lua')
script:using('modules/routes/sv_oldroute_convert.lua')
script:using('modules/routes/sh_seat_saver.lua')
script:using('modules/spawner/actors/sh_actor_remover.lua')
script:using('modules/spawner/actors/sv_actor_remover.lua')
script:using('modules/spawner/actors/sv_actor_spawner.lua')
script:using('modules/spawner/sv_dv_spawner.lua')
script:using('modules/spawner/sv_dv_remover.lua')
script:using('modules/quest_dialogue/sv_parent_dialogue.lua')
script:using('modules/states/sv_arrest.lua')
script:using('modules/states/sv_dialogue.lua')
script:using('modules/states/sv_walk.lua')
script:using('modules/states/wanted/sh_wanted_class.lua')
script:using('modules/states/wanted/sv_wanted_actions.lua')
script:using('modules/states/wanted/cl_wanted_sync.lua')
script:using('modules/states/wanted/cl_visual_wanted.lua')
script:using('modules/states/steal_money/sv_darkrp.lua')
script:using('modules/states/steal_money/sv_n2money.lua')
script:using('modules/states/steal_money/sv_sandbox.lua')
script:using('modules/ambient/cl_ambient_sound.lua')
script:using('modules/dv/sv_fix_autoload_routes.lua')
script:using('modules/dv/sv_move_to_target.lua')
script:using('modules/dv/sv_car_damage_reaction.lua')
script:using('modules/sv_nbc_npc_remover_bypass.lua')
script:using('modules/synchronization/cl_cync.lua')
script:using('modules/synchronization/sv_cync.lua')
script:using('modules/cl_version_checker.lua')
script:using('modules/sh_gm_construct_fixed_dark_room.lua')
script:using('modules/sv_bsmod_animation_fixed.lua')

script:using('actions/sv_open_door.lua')
script:using('actions/sv_police_luggage.lua')
script:using('actions/sv_damage_reaction.lua')
script:using('actions/sv_killed_actor.lua')
script:using('actions/sv_reset_targets.lua')
script:using('actions/sv_self_damage.lua')
script:using('actions/sv_player_spawn_sync_actors.lua')
script:using('actions/sv_reaction_to_a_shot.lua')
script:using('actions/sv_movement_service.lua')
script:using('actions/sv_enemy_controller.lua')
script:using('actions/sv_state_randomize.lua')

script:using('states/sv_impingement.lua')
script:using('states/sv_defense.lua')
script:using('states/sv_fear.lua')
script:using('states/sv_walk.lua')
script:using('states/sv_calling_police.lua')
script:using('states/sv_idle.lua')
script:using('states/sv_arrest.lua')
script:using('states/sv_dialogue.lua')
script:using('states/sv_sit_to_chair.lua')
script:using('states/sv_sit_to_chair_2.lua')
script:using('states/sv_retreat.lua')
script:using('states/sv_steal.lua')
script:using('states/sv_zombie.lua')
script:using('states/sv_killer.lua')
script:using('states/sv_dyspnea.lua')
script:using('states/sv_run_from_danger.lua')
script:using('states/sv_arrest_surrender.lua')

script:using('tool_options/cl_bgn_settings_menu.lua')
script:using('tool_options/cl_lang.lua')
script:using('tool_options/cl_general_settings.lua')
script:using('tool_options/cl_spawn_settings.lua')
script:using('tool_options/cl_state_settings.lua')
script:using('tool_options/cl_active_npc_group_settings.lua')
script:using('tool_options/cl_optimization_settings.lua')
script:using('tool_options/cl_client_settings.lua')
script:using('tool_options/cl_workshop_settings.lua')
script:using('tool_options/cl_unit_testing.lua')
script:using('tool_options/cl_wanted_settings.lua')

script:using('tests/cl_test_start.lua')
script:using('tests/unit/sv_unit_mod_enabled.lua')
script:using('tests/unit/sv_unit_test_exist_nodes.lua')
script:using('tests/unit/sv_unit_dv_points_exists.lua')

slib.usingDirectory(root_directory .. '/custom_modules/postload',
	'[Background NPCs | Custom modules] Script load - {file}')

hook.Add('PostGamemodeLoaded', 'BGN_PostGamemodeLoaded', function()
	hook.Run('BGN_PostGamemodeLoaded')
	hook.Remove('PostGamemodeLoaded', 'BGN_PostGamemodeLoaded')
end)

hook.Add('BGN_PostGamemodeLoaded', 'BGN_LoadConfig_SH_Player', function()
	include(root_directory .. '/config/sh_player.lua')
end)