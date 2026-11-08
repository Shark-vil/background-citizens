bgNPC.cvar = bgNPC.cvar or {}
bgNPC.cvar.bgn_enable = 1
bgNPC.cvar.bgn_debug = 0
bgNPC.cvar.bgn_fasted_teleport = 0
bgNPC.cvar.bgn_max_npc = 35
bgNPC.cvar.bgn_dynamic_nodes = 1
bgNPC.cvar.bgn_dynamic_nodes_save_progress = 1
bgNPC.cvar.bgn_dynamic_nodes_radius = 1000
bgNPC.cvar.bgn_spawn_radius = 3000
bgNPC.cvar.bgn_disable_logic_radius = 500
bgNPC.cvar.bgn_spawn_radius_visibility = 2500
bgNPC.cvar.bgn_spawn_block_radius = 600
bgNPC.cvar.bgn_spawn_period = 1
bgNPC.cvar.bgn_runtime_generator_grid_offset = 200
bgNPC.cvar.bgn_tool_point_editor_autoparent = 1
bgNPC.cvar.bgn_tool_point_editor_autoalignment = 1
bgNPC.cvar.bgn_point_z_limit = 100
bgNPC.cvar.bgn_enable_wanted_mode = 1
bgNPC.cvar.bgn_wanted_time = 30
bgNPC.cvar.bgn_wanted_level = 1
bgNPC.cvar.bgn_cl_disable_hud_local = 0
bgNPC.cvar.bgn_wanted_hud_text = 1
bgNPC.cvar.bgn_wanted_hud_stars = 1
bgNPC.cvar.bgn_wanted_impunity_limit = 5
bgNPC.cvar.bgn_wanted_impunity_reduction_period = 10
bgNPC.cvar.bgn_wanted_police_instantly = 1
bgNPC.cvar.bgn_arrest_mode = 1
bgNPC.cvar.bgn_arrest_time = 5
bgNPC.cvar.bgn_arrest_time_limit = 20
bgNPC.cvar.bgn_ignore_another_npc = 0
bgNPC.cvar.bgn_team_damage = 0
bgNPC.cvar.bgn_shot_sound_mode = 0
bgNPC.cvar.bgn_cl_disable_halo = 0
bgNPC.cvar.bgn_disable_halo_wanted = 0
bgNPC.cvar.bgn_disable_halo_calling = 0
bgNPC.cvar.bgn_cl_disable_self_halo_wanted = 1
bgNPC.cvar.bgn_enable_dv_support = 1
bgNPC.cvar.bgn_enable_police_system_support = 1
bgNPC.cvar.bgn_disable_dialogues = 0
bgNPC.cvar.bgn_tool_draw_distance = 1000
bgNPC.cvar.bgn_tool_point_editor_show_parents = 1
bgNPC.cvar.bgn_actors_teleporter = 1
bgNPC.cvar.bgn_actors_max_teleports = 3
bgNPC.cvar.bgn_tool_seat_offset_pos_x = 0
bgNPC.cvar.bgn_tool_seat_offset_pos_y = 0
bgNPC.cvar.bgn_tool_seat_offset_pos_z = 0
bgNPC.cvar.bgn_tool_seat_offset_angle_x = 0
bgNPC.cvar.bgn_tool_seat_offset_angle_y = 0
bgNPC.cvar.bgn_tool_seat_offset_angle_z = 0
bgNPC.cvar.bgn_cl_draw_npc_path = 0
bgNPC.cvar.bgn_cl_field_view_optimization = 1
bgNPC.cvar.bgn_cl_field_view_optimization_range = 500
bgNPC.cvar.bgn_cl_ambient_sound = 1
bgNPC.cvar.bgn_cl_ghost_crowd = 0
bgNPC.cvar.bgn_cl_ghost_crowd_max = 40
bgNPC.cvar.bgn_module_replics_enable = 1
bgNPC.cvar.bgn_module_replics_language = 'auto'
bgNPC.cvar.bgn_module_bio_annihilation_two_replacement = 0
bgNPC.cvar.bgn_module_arccw_weapon_replacement = 0
bgNPC.cvar.bgn_module_arc9_weapon_replacement = 0
-- bgNPC.cvar.bgn_module_mw_weapon_replacement = 0
bgNPC.cvar.bgn_module_tfa_weapon_replacement = 0
bgNPC.cvar.bgn_all_models_random = 0
bgNPC.cvar.bgn_peaceful_mode = 0
bgNPC.cvar.bgn_module_stormfox2 = 0
bgNPC.cvar.bgn_module_custom_gestures = 0
bgNPC.cvar.bgn_module_tactical_groups = 1
bgNPC.cvar.bgn_module_followers_mod_addon = 1
bgNPC.cvar.bgn_drop_money = 1
bgNPC.cvar.bgn_module_n2money = 1
bgNPC.cvar.bgn_agressive_mode = 0
bgNPC.cvar.bgn_friend_mode = 0
bgNPC.cvar.bgn_brain = 'auto'
bgNPC.cvar.bgn_actor_body = 'auto'
bgNPC.cvar.bgn_nav_provider = 'auto'
bgNPC.cvar.bgn_nav_generator_max_nodes = 15000
bgNPC.cvar.bgn_lod_near_radius = 2500

CreateConVar('bgn_installed', 1, {
	FCVAR_ARCHIVE,
	FCVAR_NOTIFY,
	FCVAR_REPLICATED,
	FCVAR_SERVER_CAN_EXECUTE
}, '')

bgNPC.CVars.Register('bgn_enable', bgNPC.cvar.bgn_enable, 'Toggles the modification activity. 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_agressive_mode', bgNPC.cvar.bgn_agressive_mode, 'All actors will be hostile towards you.')

bgNPC.CVars.Register('bgn_friend_mode', bgNPC.cvar.bgn_friend_mode, 'All actors will be friendly towards you.')

bgNPC.CVars.Register('bgn_dynamic_nodes_radius', bgNPC.cvar.bgn_dynamic_nodes_radius, '')

bgNPC.CVars.Register('bgn_drop_money', bgNPC.cvar.bgn_drop_money, 'Enables the ability to drop money from NPCs when they die. Invokes hook "BGN_DropMoney". 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_module_n2money', bgNPC.cvar.bgn_module_n2money, 'Enables a money drop from the addon "nMoney2 - Sandbox Currency". 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_debug', bgNPC.cvar.bgn_debug, 'Turns on debug mode and prints additional information to the console. 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_dynamic_nodes_save_progress', bgNPC.cvar.bgn_dynamic_nodes_save_progress, 'If enabled, the automatically-generated movement mesh will not be deleted with each new generation, 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_fasted_teleport', bgNPC.cvar.bgn_fasted_teleport, 'Enables fast teleportation of NPCs. Disable this if you experience performance issues. 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_peaceful_mode', bgNPC.cvar.bgn_peaceful_mode, 'Disables any skirmishes between NPCs. They will just walk around so you don\'t feel lonely.. 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_module_stormfox2', bgNPC.cvar.bgn_module_stormfox2, 'Includes support for the "StormFox2" addon. 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_enable_wanted_mode', bgNPC.cvar.bgn_enable_wanted_mode, 'Enables or disables wanted mode.')

bgNPC.CVars.Register('bgn_wanted_time', bgNPC.cvar.bgn_wanted_time, 'The time you need to go through to remove the wanted level.')

bgNPC.CVars.Register('bgn_wanted_level', bgNPC.cvar.bgn_wanted_level, 'Enables or disables the boost wanted level mode.')

bgNPC.CVars.Register('bgn_wanted_hud_text', bgNPC.cvar.bgn_wanted_hud_text, 'Enables or disables the text about wanted time.')

bgNPC.CVars.Register('bgn_wanted_hud_stars', bgNPC.cvar.bgn_wanted_hud_stars, 'Enables or disables drawing of stars in wanted mode.')

bgNPC.CVars.Register('bgn_wanted_impunity_limit', bgNPC.cvar.bgn_wanted_impunity_limit, 'Sets the number of kills, on reaching which you are guaranteed to get a wanted level. The value "0" disables the option.')

bgNPC.CVars.Register('bgn_wanted_impunity_reduction_period', bgNPC.cvar.bgn_wanted_impunity_reduction_period, 'Sets the wanted in seconds after which players have their kill limit reduced by 1 number. The value "0" disables the option.')

bgNPC.CVars.Register('bgn_wanted_police_instantly', bgNPC.cvar.bgn_wanted_police_instantly, 'If enabled, you instantly get a wanted level when killing actors from the "police" team.')

bgNPC.CVars.Register('bgn_max_npc', bgNPC.cvar.bgn_max_npc, 'The maximum number of background NPCs on the map.')

bgNPC.CVars.Register('bgn_spawn_radius', bgNPC.cvar.bgn_spawn_radius, 'NPC spawn radius relative to the player.')

bgNPC.CVars.Register('bgn_disable_logic_radius', bgNPC.cvar.bgn_disable_logic_radius, 'Determines at what distance the NPC will disable logic for optimization purposes')

bgNPC.CVars.Register('bgn_spawn_radius_visibility', bgNPC.cvar.bgn_spawn_radius_visibility, 'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.')

bgNPC.CVars.Register('bgn_spawn_block_radius', bgNPC.cvar.bgn_spawn_block_radius, 'Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker')

bgNPC.CVars.Register('bgn_spawn_period', bgNPC.cvar.bgn_spawn_period, 'The period between the spawn of the NPC. Changes require a server restart.')

bgNPC.CVars.Register('bgn_point_z_limit', bgNPC.cvar.bgn_point_z_limit, 'Height limit between points. Used to correctly define child points.')

bgNPC.CVars.Register('bgn_arrest_mode', bgNPC.cvar.bgn_arrest_mode, 'Includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.')

bgNPC.CVars.Register('bgn_arrest_time', bgNPC.cvar.bgn_arrest_time, 'Sets the time allotted for your detention.')

bgNPC.CVars.Register('bgn_arrest_time_limit', bgNPC.cvar.bgn_arrest_time_limit, 'Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.')

bgNPC.CVars.Register('bgn_team_damage', bgNPC.cvar.bgn_team_damage, 'Actors of one team damage each other (they still never fight back). 1 - enabled, 0 - disabled.')

bgNPC.CVars.Register('bgn_ignore_another_npc', bgNPC.cvar.bgn_ignore_another_npc, 'If this parameter is active, then NPCs will ignore any other spawned NPCs.')

bgNPC.CVars.Register('bgn_shot_sound_mode', bgNPC.cvar.bgn_shot_sound_mode, 'If enabled, then NPCs will react to the sound of a shot as if someone was shooting at an ally. (Warning: this function is experimental and not recommended for use)')

bgNPC.CVars.Register('bgn_disable_halo_calling', bgNPC.cvar.bgn_disable_halo_calling, 'Disable halo for actors calling the police.')

bgNPC.CVars.Register('bgn_disable_halo_wanted', bgNPC.cvar.bgn_disable_halo_wanted, 'Disable halo for wanted entities.')

bgNPC.CVars.Register('bgn_enable_dv_support', bgNPC.cvar.bgn_enable_dv_support, 'Includes compatibility with the "DV" addon and forces NPCs to use vehicles.')

bgNPC.CVars.Register('bgn_enable_police_system_support', bgNPC.cvar.bgn_enable_police_system_support, 'Enables compatibility with the "Police System" addon and overrides the default arrest method.')

bgNPC.CVars.Register('bgn_disable_dialogues', bgNPC.cvar.bgn_disable_dialogues, 'Activate this if you want to disable dialogues between NPCs.')

bgNPC.CVars.Register('bgn_actors_teleporter', bgNPC.cvar.bgn_actors_teleporter, 'Instead of removing the NPC after losing it from the players field of view, it will teleport to the nearest point. This will create the effect of a more populated city. Disable this option if you notice dropped frames.')

bgNPC.CVars.Register('bgn_actors_max_teleports', bgNPC.cvar.bgn_actors_max_teleports, 'How many NPCs can be teleported in one second. The larger the number, the more calculations will be performed. The teleport is calculated for each actor individually, without waiting for the teleport of another actor from his group.')

bgNPC.CVars.Register('bgn_module_replics_language', bgNPC.cvar.bgn_module_replics_language, 'Language of the NPC phrases: auto (game language), english, russian.')

bgNPC.CVars.Register('bgn_module_replics_enable', bgNPC.cvar.bgn_module_replics_enable, 'Enables or disables NPC text replics.')

bgNPC.CVars.Register('bgn_module_bio_annihilation_two_replacement',
	bgNPC.cvar.bgn_module_bio_annihilation_two_replacement, '1 - Enable "BA2" addon support. 0 - disable.')

bgNPC.CVars.Register('bgn_dynamic_nodes', bgNPC.cvar.bgn_dynamic_nodes, '1 - Enable dynamic movement mesh. 0 - disable.')

bgNPC.CVars.Register('bgn_module_arccw_weapon_replacement', bgNPC.cvar.bgn_module_arccw_weapon_replacement, '1 - includes the replacement of weapons. 0 - disables.')

bgNPC.CVars.Register('bgn_module_arc9_weapon_replacement', bgNPC.cvar.bgn_module_arc9_weapon_replacement, '1 - includes the replacement of weapons. 0 - disables.')

-- bgNPC.CVars.Register('bgn_module_mw_weapon_replacement', bgNPC.cvar.bgn_module_mw_weapon_replacement,
-- 	FCVAR_ARCHIVE, '1 - includes the replacement of weapons. 0 - disables.')
--

bgNPC.CVars.Register('bgn_module_tfa_weapon_replacement', bgNPC.cvar.bgn_module_tfa_weapon_replacement, '1 - includes the replacement of weapons. 0 - disables.')

bgNPC.CVars.Register('bgn_module_custom_gestures', bgNPC.cvar.bgn_module_custom_gestures, '1 - Enable custom gestures animations. 0 - disables.')

bgNPC.CVars.Register('bgn_module_tactical_groups', bgNPC.cvar.bgn_module_tactical_groups, '1 - Enable tactical groups. 0 - disables.')

bgNPC.CVars.Register('bgn_module_followers_mod_addon', bgNPC.cvar.bgn_module_followers_mod_addon, '1 - Enable sopport addon "Followers Mod". 0 - disables.')

bgNPC.CVars.Register('bgn_all_models_random', bgNPC.cvar.bgn_all_models_random, '1 - makes any NPCs with random models from the list. 0 - disables.')

bgNPC.CVars.Register('bgn_runtime_generator_grid_offset', bgNPC.cvar.bgn_runtime_generator_grid_offset, 'Offset between points for grid generation')

-- Created by their systems on the server too (same defaults); registered here so the settings window can change them.
bgNPC.CVars.Register('bgn_brain', bgNPC.cvar.bgn_brain, 'Background NPCs: actor brain type (auto, fsm, goap)')
bgNPC.CVars.Register('bgn_actor_body', bgNPC.cvar.bgn_actor_body, 'Background NPCs: actor body (auto - NextBot on NavMesh maps, npc, nextbot)')
bgNPC.CVars.Register('bgn_nav_provider', bgNPC.cvar.bgn_nav_provider, 'Background NPCs: navigation source (auto, navmesh, nodegraph, custom)')
bgNPC.CVars.Register('bgn_nav_generator_max_nodes', bgNPC.cvar.bgn_nav_generator_max_nodes, 'Background NPCs: node limit of the generator')
bgNPC.CVars.Register('bgn_lod_near_radius', bgNPC.cvar.bgn_lod_near_radius, 'Background NPCs: actors closer than this to a player get full updates')

for npcType, v in pairs(bgNPC.cfg.actors) do
	local enabled = 0
	if v.enabled then enabled = 1 end

	bgNPC.CVars.Register('bgn_npc_type_' .. npcType, enabled)
end

for npcType, v in pairs(bgNPC.cfg.actors) do
	bgNPC.CVars.Register('bgn_npc_type_max_' .. npcType, bgNPC.Config.GetFullness(npcType))
end

for npcType, v in pairs(bgNPC.cfg.actors) do
	bgNPC.CVars.Register('bgn_disable_weapon_' .. npcType , 0)
end

for npcType, v in pairs(bgNPC.cfg.actors) do
	local max_vehicle = v.max_vehicle or 0
	bgNPC.CVars.Register('bgn_npc_vehicle_max_' .. npcType, max_vehicle)
end