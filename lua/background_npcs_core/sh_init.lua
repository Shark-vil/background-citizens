--[[
	Background NPCs entry point (included from lua/autorun/background_npcs.lua).
	Docs: https://shark-vil.github.io/background-citizens
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
bgNPC.VERSION = '1.13.7'

-- Do not change -------------
bgNPC.LANGUAGES = {}
bgNPC.cfg = {}
bgNPC.actors = {}
bgNPC.factors = {}
bgNPC.npcs = {}
bgNPC.fnpcs = {}
bgNPC.actors_by_uid = {}
bgNPC.points = {}
-- bgNPC.wanted = {}
-- bgNPC.killing_statistic = {}
-- bgNPC.wanted_killing_statistic = {}
bgNPC.respawn_actors_delay = {}
bgNPC.DVCars = {}
bgNPC.state_actions = {}
bgNPC.state_actions_groups = {}
bgNPC.SpawnArea = bgNPC.SpawnArea or {}
bgNPC.SpawnMenu = bgNPC.SpawnMenu or {}
bgNPC.SpawnMenu.Creator = bgNPC.SpawnMenu.Creator or {
	['NPC'] = {},
	['Default'] = {}
}
-- ---------------------------

local ROOT = 'background_npcs_core'

-- Includes a file by its realm prefix: sh_ (both), sv_ (server), cl_ (client).
-- send_only: only AddCSLuaFile, the file is included by another script.
local function Include(path, send_only)
	path = ROOT .. '/' .. path
	local prefix = string.match(path, '([^/]+)$'):sub(1, 3)

	if prefix == 'sv_' then
		if SERVER and not send_only then include(path) end
		return
	end

	if prefix ~= 'sh_' and prefix ~= 'cl_' then
		ErrorNoHalt('[Background NPCs] File without realm prefix is skipped: ' .. path .. '\n')
		return
	end

	if SERVER then AddCSLuaFile(path) end
	if send_only then return end
	if prefix == 'sh_' or CLIENT then include(path) end
end

-- Includes every file of a directory (recursively): sh_ first, then sv_, then cl_.
local function IncludeDir(dir)
	local files, directories = file.Find(dir .. '/*', 'LUA')
	table.sort(files)

	for _, prefix in ipairs({ 'sh_', 'sv_', 'cl_' }) do
		for _, name in ipairs(files) do
			if name:sub(1, 3) == prefix then Include(string.sub(dir, #ROOT + 2) .. '/' .. name) end
		end
	end

	for _, sub_dir in ipairs(directories) do IncludeDir(dir .. '/' .. sub_dir) end
end

local function ExecutableScripts()
	-- Core layer (no external libraries)
	Include('core/sh_class.lua')
	Include('core/sh_net.lua')
	Include('core/sh_util.lua')
	Include('core/sh_tasks.lua')
	Include('core/sh_player_ready.lua')
	Include('core/sh_cvars.lua')
	Include('core/sh_commands.lua')
	Include('core/sh_spatial_grid.lua')
	Include('core/sh_animator.lua')
	Include('core/sh_selftest.lua')

	Include('config/sh_main.lua')
	Include('config/sh_config.lua')

	IncludeDir(ROOT .. '/config/actors')

	Include('config/replics/sh_init.lua')
	Include('config/sh_names.lua')
	Include('config/sh_shot_sound.lua')
	Include('config/sh_player.lua')
	Include('config/gamemodes/sh_darkrp.lua')
	Include('config/sh_ambient.lua')

	Include('config/states/sh_wanted.lua')
	Include('config/states/sh_arrest.lua')
	Include('config/states/sh_dialogue.lua')
	Include('config/states/sh_sit_chair.lua')

	IncludeDir(ROOT .. '/custom_modules/config')

	Include('config/sh_oldconfig.lua')

	-- Public API. Loaded before console variables, which already use it.
	Include('api/sh_assert.lua')
	Include('api/sh_core.lua')
	Include('api/sh_config.lua')
	Include('api/sh_actors.lua')
	Include('api/sh_points.lua')
	Include('api/sh_states.lua')
	Include('api/sh_vision.lua')
	Include('api/sh_modes.lua')
	Include('api/sh_statistics.lua')
	Include('api/sv_combat.lua')
	Include('api/sh_legacy.lua')

	Include('cvars/sh_cvars.lua')
	Include('cvars/sv_cvars.lua')
	Include('cvars/cl_cvars.lua')

	Include('commands/sh_cmd_config.lua')
	Include('commands/sh_cmd_autogenerator.lua')

	IncludeDir(ROOT .. '/custom_modules/preload')

	-- Remember actor configs (including custom modules) for bgNPC.Config.Reset
	bgNPC.Config.SaveDefaults()

	Include('classes/actor/sh_actor_base.lua', true)
	Include('classes/actor/cl_actor_text_say.lua')
	Include('classes/actor/sh_actor_class.lua')
	Include('classes/actor/sh_actor_animations.lua')
	Include('classes/sh_node_class.lua')
	Include('classes/sh_seat_class.lua')
	Include('classes/sh_dv_class.lua')

	Include('modules/cl_fonts.lua')
	Include('global/sv_spawner.lua')

	Include('modules/modes/sv_peaceful_mode.lua')
	Include('modules/modes/sv_friend_and_aggressive_mode.lua')
	Include('modules/relationship/sv_relationship.lua')

	-- Include('modules/cl_updatepage.lua')
	Include('modules/cl_render_optimization.lua')

	Include('modules/dynamic_movement_mesh/sv_dynamic_movement_mesh.lua')
	Include('modules/dynamic_movement_mesh/cl_dynamic_movement_mesh.lua')

	Include('modules/sv_run_logic_optimization.lua')

	Include('modules/debug/cl_render_target_path.lua')
	Include('modules/debug/sv_movement_render.lua')
	Include('modules/debug/cl_movement_render.lua')
	Include('modules/debug/sh_draw_chunks.lua')

	Include('modules/sv_npc_look_at_object.lua')
	Include('modules/sv_player_look_at_object.lua')
	Include('modules/sv_static_animation_controller.lua')
	Include('modules/sv_first_attacker_found.lua')
	Include('modules/sv_zombie_mode.lua')
	Include('modules/sv_dropmoney.lua')
	Include('modules/sv_n2money_drop.lua')

	Include('modules/weapons/sv_weapon_replacment.lua')

	Include('modules/npcs/sv_police_helicopter_spawn_rules.lua')
	Include('modules/npcs/sv_set_citizen_model.lua')
	Include('modules/npcs/sv_set_gangster_model.lua')
	Include('modules/npcs/sv_set_custom_health.lua')
	Include('modules/npcs/sv_police_voice.lua')
	Include('modules/npcs/sv_random_voice.lua')
	Include('modules/npcs/sv_bio_annihilation_two.lua')
	Include('modules/npcs/sv_regeneration.lua')

	Include('modules/cl_updatepage.lua')

	Include('modules/player/sv_team_parent.lua')

	Include('modules/darkrp/sv_darkrp_drop_money.lua')
	Include('modules/darkrp/sv_remove_wanted_if_arrest.lua')
	Include('modules/darkrp/sv_change_team_wanted.lua')
	Include('modules/darkrp/sv_disable_door_open.lua')

	Include('modules/arrest/sv_police_system.lua')
	Include('modules/arrest/sv_darkrp_arrest.lua')

	Include('modules/routes/sh_route_saver.lua')
	Include('modules/routes/loader/sv_loader.lua')
	Include('modules/routes/loader/cl_loader.lua')
	Include('modules/routes/compile/sv_compile.lua')
	Include('modules/routes/compile/cl_compile.lua')
	Include('modules/routes/sv_oldroute_convert.lua')
	Include('modules/routes/sh_seat_saver.lua')

	Include('modules/spawner/actors/sh_actor_remover.lua')
	Include('modules/spawner/actors/sv_actor_remover.lua')
	Include('modules/spawner/actors/sv_actor_spawner.lua')
	Include('modules/spawner/actors/sv_zone_spawner.lua')
	Include('modules/spawner/sv_dv_spawner.lua')
	Include('modules/spawner/sv_dv_remover.lua')

	Include('modules/quest_dialogue/sv_parent_dialogue.lua')

	Include('modules/states/sv_arrest.lua')
	Include('modules/states/sv_dialogue.lua')
	Include('modules/states/wanted/sh_wanted_class.lua')
	Include('modules/states/wanted/sv_wanted_actions.lua')
	Include('modules/states/wanted/cl_wanted_sync.lua')
	Include('modules/states/wanted/cl_visual_wanted.lua')
	Include('modules/states/steal_money/sv_darkrp.lua')
	Include('modules/states/steal_money/sv_n2money.lua')
	Include('modules/states/steal_money/sv_sandbox.lua')

	Include('modules/ambient/cl_ambient_sound.lua')

	Include('modules/dv/sv_fix_autoload_routes.lua')
	Include('modules/dv/sv_move_to_target.lua')
	Include('modules/dv/sv_car_damage_reaction.lua')

	Include('modules/sv_nbc_npc_remover_bypass.lua')

	Include('modules/synchronization/cl_sync.lua')
	Include('modules/synchronization/sv_sync.lua')

	Include('modules/cl_version_checker.lua')

	Include('modules/sv_inpc.lua')
	Include('modules/sv_enhanced_npc.lua')
	Include('modules/sv_scenic_npc.lua')

	Include('modules/sv_bsmod_animation_fixed.lua')
	Include('modules/sv_build_x_support.lua')
	Include('modules/sv_followers_mod.lua')
	Include('modules/stormfox/sv_stormfox_limits.lua')

	Include('modules/tactical_groups/sv_group.lua')

	Include('actions/sh_state_machine.lua')
	Include('actions/sv_open_door.lua')
	Include('actions/sv_police_luggage.lua')
	Include('actions/sv_damage_reaction.lua')
	Include('actions/sv_killed_actor.lua')
	Include('actions/cl_killed_actor.lua')
	Include('actions/sv_self_damage.lua')
	Include('actions/sv_player_spawn_sync_actors.lua')
	Include('actions/sv_reaction_to_a_shot.lua')
	Include('actions/sv_movement_service.lua')
	Include('actions/sv_enemy_controller.lua')
	Include('actions/sv_state_randomize.lua')
	Include('actions/sv_actors_think.lua')

	Include('states/sv_impingement.lua')
	Include('states/sv_defense.lua')
	Include('states/sv_fear.lua')
	Include('states/sv_walk.lua')
	Include('states/sv_calling_police.lua')
	Include('states/sv_idle.lua')
	Include('states/sv_arrest.lua')
	Include('states/sv_dialogue.lua')
	Include('states/sv_sit_to_chair.lua')
	Include('states/sv_sit_to_chair_2.lua')
	Include('states/sv_retreat.lua')
	Include('states/sv_steal.lua')
	Include('states/sv_zombie.lua')
	Include('states/sv_killer.lua')
	Include('states/sv_dyspnea.lua')
	Include('states/sv_run_from_danger.lua')
	Include('states/sv_arrest_surrender.lua')
	Include('states/sv_random_gesture.lua')
	Include('states/sh_dance.lua')
	Include('states/sh_scenic_npc.lua')
	Include('states/sh_go_to_police_car.lua')

	Include('tool_options/lang/sh_en.lua')
	Include('tool_options/lang/sh_ru.lua')
	Include('tool_options/cl_lang.lua')

	Include('tool_options/cl_bgn_settings_menu.lua')
	Include('tool_options/cl_general_settings.lua')
	Include('tool_options/cl_spawn_settings.lua')
	Include('tool_options/cl_state_settings.lua')
	Include('tool_options/cl_active_npc_group_settings.lua')
	Include('tool_options/cl_optimization_settings.lua')
	Include('tool_options/cl_client_settings.lua')
	Include('tool_options/cl_workshop_settings.lua')
	Include('tool_options/cl_wanted_settings.lua')
	Include('tool_options/cl_generation_settings.lua')
	Include('tool_options/cl_addons_settings.lua')
	Include('tool_options/cl_arrest_settings.lua')

	Include('modules/spawnmenu/cl_spawnmenu.lua')
	Include('modules/spawnmenu/sv_spawnmenu.lua')
	Include('modules/spawnmenu/sh_spawnmenu.lua')


	IncludeDir(ROOT .. '/custom_modules/postload')
end

ExecutableScripts()

hook.Add('BGN_PostGamemodeLoaded', 'BGN_LoadConfig_SH_Player', function()
	include(ROOT .. '/config/sh_player.lua')
end)

hook.Add('PostGamemodeLoaded', 'BGN_PostGamemodeLoaded', function()
	hook.Run('BGN_PostGamemodeLoaded')
	hook.Remove('PostGamemodeLoaded', 'BGN_PostGamemodeLoaded')
end)

bgNPC.Commands.Register('bgn_scripts_reload', {
	admin = true,
	broadcast = true,
	help = 'Reloads all scripts of the addon.',
	server = function()
		ExecutableScripts()
		include(ROOT .. '/config/sh_player.lua')
		bgNPC.LoadRoutes()
	end,
	client = function()
		ExecutableScripts()
		include(ROOT .. '/config/sh_player.lua')
	end,
})
