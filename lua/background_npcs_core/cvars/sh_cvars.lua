local DefaultAccess = { isAdmin = true }

bgNPC.cvar = bgNPC.cvar or {}
bgNPC.cvar.bgn_enable = 1
bgNPC.cvar.bgn_debug = 0
bgNPC.cvar.bgn_fasted_teleport = 0
bgNPC.cvar.bgn_max_npc = 35
bgNPC.cvar.bgn_enable_dynamic_nodes_only_when_mesh_not_exists = 1
bgNPC.cvar.bgn_dynamic_nodes = 1
bgNPC.cvar.bgn_dynamic_nodes_type = 'grid'
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
bgNPC.cvar.bgn_module_replics_enable = 1
bgNPC.cvar.bgn_module_replics_language = 'english'
bgNPC.cvar.bgn_module_bio_annihilation_two_replacement = 0
bgNPC.cvar.bgn_module_arccw_weapon_replacement = 1
bgNPC.cvar.bgn_all_models_random = 0
bgNPC.cvar.bgn_peaceful_mode = 0
bgNPC.cvar.bgn_module_stormfox2 = 0
bgNPC.cvar.bgn_module_custom_gestures = 0
bgNPC.cvar.bgn_module_tactical_groups = 0
bgNPC.cvar.bgn_module_followers_mod_addon = 1

function bgNPC:IsActiveNPCType(npc_type)
	local cvar = GetConVar('bgn_npc_type_' .. npc_type)
	if not cvar then return false end
	return cvar:GetBool()
end

function bgNPC:GetFullness(npc_type)
	local data = bgNPC.cfg.actors[npc_type]
	if data == nil then
		return 0
	end

	if data.fullness ~= nil then
		local max = math.Round( (data.fullness / 100) * GetConVar('bgn_max_npc'):GetInt() )
		if max >= 0 then return max end
	elseif data.limit ~= nil then
		return math.Round(data.limit)
	end

	return 0
end

function bgNPC:GetLimitActors(npc_type)
	return GetConVar('bgn_npc_type_max_' .. npc_type):GetInt()
end

CreateConVar('bgn_installed', 1, {
	FCVAR_ARCHIVE,
	FCVAR_NOTIFY,
	FCVAR_REPLICATED,
	FCVAR_SERVER_CAN_EXECUTE
}, '')

scvar.Register('bgn_enable', bgNPC.cvar.bgn_enable,
	FCVAR_ARCHIVE, 'Toggles the modification activity. 1 - enabled, 0 - disabled.')
	.Access(DefaultAccess)

scvar.Register('bgn_debug', bgNPC.cvar.bgn_debug,
	FCVAR_ARCHIVE, 'Turns on debug mode and prints additional information to the console.')
	.Access(DefaultAccess)

scvar.Register('bgn_fasted_teleport', bgNPC.cvar.bgn_fasted_teleport,
	FCVAR_ARCHIVE, 'Enables fast teleportation of NPCs. Disable this if you experience performance issues. 1 - enabled, 0 - disabled.')
	.Access(DefaultAccess)

scvar.Register('bgn_peaceful_mode', bgNPC.cvar.bgn_peaceful_mode,
	FCVAR_ARCHIVE, 'Disables any skirmishes between NPCs. They will just walk around so you don\'t feel lonely.. 1 - enabled, 0 - disabled.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_stormfox2', bgNPC.cvar.bgn_module_stormfox2,
	FCVAR_ARCHIVE, 'Includes support for the "StormFox2" addon. 1 - enabled, 0 - disabled.')
	.Access(DefaultAccess)

scvar.Register('bgn_enable_wanted_mode', bgNPC.cvar.bgn_enable_wanted_mode,
	FCVAR_ARCHIVE, 'Enables or disables wanted mode.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_time', bgNPC.cvar.bgn_wanted_time,
	FCVAR_ARCHIVE, 'The time you need to go through to remove the wanted level.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_level', bgNPC.cvar.bgn_wanted_level,
	FCVAR_ARCHIVE, 'Enables or disables the boost wanted level mode.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_hud_text', bgNPC.cvar.bgn_wanted_hud_text,
	FCVAR_ARCHIVE, 'Enables or disables the text about wanted time.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_hud_stars', bgNPC.cvar.bgn_wanted_hud_stars,
	FCVAR_ARCHIVE, 'Enables or disables drawing of stars in wanted mode.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_impunity_limit', bgNPC.cvar.bgn_wanted_impunity_limit,
	FCVAR_ARCHIVE, 'Sets the number of kills, on reaching which you are guaranteed to get a wanted level. The value "0" disables the option.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_impunity_reduction_period', bgNPC.cvar.bgn_wanted_impunity_reduction_period,
	FCVAR_ARCHIVE, 'Sets the wanted in seconds after which players have their kill limit reduced by 1 number. The value "0" disables the option.')
	.Access(DefaultAccess)

scvar.Register('bgn_wanted_police_instantly', bgNPC.cvar.bgn_wanted_police_instantly,
	FCVAR_ARCHIVE, 'If enabled, you instantly get a wanted level when killing actors from the "police" team.')
	.Access(DefaultAccess)

scvar.Register('bgn_max_npc', bgNPC.cvar.bgn_max_npc,
	FCVAR_ARCHIVE, 'The maximum number of background NPCs on the map.')
	.Access(DefaultAccess)

scvar.Register('bgn_spawn_radius', bgNPC.cvar.bgn_spawn_radius,
	FCVAR_ARCHIVE, 'NPC spawn radius relative to the player.')
	.Access(DefaultAccess)

scvar.Register('bgn_disable_logic_radius', bgNPC.cvar.bgn_disable_logic_radius,
	FCVAR_ARCHIVE, 'Determines at what distance the NPC will disable logic for optimization purposes')
	.Access(DefaultAccess)

scvar.Register('bgn_spawn_radius_visibility', bgNPC.cvar.bgn_spawn_radius_visibility,
	FCVAR_ARCHIVE, 'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.')
	.Access(DefaultAccess)

scvar.Register('bgn_spawn_block_radius', bgNPC.cvar.bgn_spawn_block_radius,
	FCVAR_ARCHIVE, 'Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker')
	.Access(DefaultAccess)

scvar.Register('bgn_spawn_period', bgNPC.cvar.bgn_spawn_period,
	FCVAR_ARCHIVE, 'The period between the spawn of the NPC. Changes require a server restart.')
	.Access(DefaultAccess)

scvar.Register('bgn_point_z_limit', bgNPC.cvar.bgn_point_z_limit,
	FCVAR_ARCHIVE, 'Height limit between points. Used to correctly define child points.')
	.Access(DefaultAccess)

scvar.Register('bgn_arrest_mode', bgNPC.cvar.bgn_arrest_mode,
	FCVAR_ARCHIVE, 'Includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.')
	.Access(DefaultAccess)

scvar.Register('bgn_arrest_time', bgNPC.cvar.bgn_arrest_time,
	FCVAR_ARCHIVE, 'Sets the time allotted for your detention.')
	.Access(DefaultAccess)

scvar.Register('bgn_arrest_time_limit', bgNPC.cvar.bgn_arrest_time_limit,
	FCVAR_ARCHIVE, 'Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.')
	.Access(DefaultAccess)

scvar.Register('bgn_ignore_another_npc', bgNPC.cvar.bgn_ignore_another_npc,
	FCVAR_ARCHIVE, 'If this parameter is active, then NPCs will ignore any other spawned NPCs.')
	.Access(DefaultAccess)

scvar.Register('bgn_shot_sound_mode', bgNPC.cvar.bgn_shot_sound_mode,
	FCVAR_ARCHIVE, 'If enabled, then NPCs will react to the sound of a shot as if someone was shooting at an ally. (Warning: this function is experimental and not recommended for use)')
	.Access(DefaultAccess)

scvar.Register('bgn_disable_halo_calling', bgNPC.cvar.bgn_disable_halo_calling,
	FCVAR_ARCHIVE, 'Disable halo for actors calling the police.')
	.Access(DefaultAccess)

scvar.Register('bgn_disable_halo_wanted', bgNPC.cvar.bgn_disable_halo_wanted,
	FCVAR_ARCHIVE, 'Disable halo for wanted entities.')
	.Access(DefaultAccess)

scvar.Register('bgn_enable_dv_support', bgNPC.cvar.bgn_enable_dv_support,
	FCVAR_ARCHIVE, 'Includes compatibility with the "DV" addon and forces NPCs to use vehicles.')
	.Access(DefaultAccess)

scvar.Register('bgn_enable_police_system_support', bgNPC.cvar.bgn_enable_police_system_support,
	FCVAR_ARCHIVE,
	'Enables compatibility with the "Police System" addon and overrides the default arrest method.'
).Access(DefaultAccess)

scvar.Register('bgn_disable_dialogues', bgNPC.cvar.bgn_disable_dialogues,
	FCVAR_ARCHIVE, 'Activate this if you want to disable dialogues between NPCs.')
	.Access(DefaultAccess)

scvar.Register('bgn_actors_teleporter', bgNPC.cvar.bgn_actors_teleporter,
	FCVAR_ARCHIVE, 'Instead of removing the NPC after losing it from the players field of view, it will teleport to the nearest point. This will create the effect of a more populated city. Disable this option if you notice dropped frames.')
	.Access(DefaultAccess)

scvar.Register('bgn_actors_max_teleports', bgNPC.cvar.bgn_actors_max_teleports,
	FCVAR_ARCHIVE, 'How many NPCs can be teleported in one second. The larger the number, the more calculations will be performed. The teleport is calculated for each actor individually, without waiting for the teleport of another actor from his group.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_replics_language', bgNPC.cvar.bgn_module_replics_language,
	FCVAR_ARCHIVE, 'Sets the language of the NPC replicas. The default is - en.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_replics_enable', bgNPC.cvar.bgn_module_replics_enable,
	FCVAR_ARCHIVE, 'Enables or disables NPC text replics.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_bio_annihilation_two_replacement',
	bgNPC.cvar.bgn_module_bio_annihilation_two_replacement,
	FCVAR_ARCHIVE, '1 - Enable "BA2" addon support. 0 - disable.')
	.Access(DefaultAccess)

scvar.Register('bgn_enable_dynamic_nodes_only_when_mesh_not_exists',
	bgNPC.cvar.bgn_enable_dynamic_nodes_only_when_mesh_not_exists,
	FCVAR_ARCHIVE, '1 - Enable dynamic movement mesh restriction. 0 - disable.')
	.Access(DefaultAccess)

scvar.Register('bgn_dynamic_nodes', bgNPC.cvar.bgn_dynamic_nodes,
	FCVAR_ARCHIVE, '1 - Enable dynamic movement mesh. 0 - disable.')
	.Access(DefaultAccess)

scvar.Register('bgn_dynamic_nodes_type', bgNPC.cvar.bgn_dynamic_nodes_type,
	FCVAR_ARCHIVE, 'Types - grid, random')
	.Access(DefaultAccess)

scvar.Register('bgn_module_arccw_weapon_replacement', bgNPC.cvar.bgn_module_arccw_weapon_replacement,
	FCVAR_ARCHIVE, '1 - includes the replacement of weapons. 0 - disables.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_custom_gestures', bgNPC.cvar.bgn_module_custom_gestures,
	FCVAR_ARCHIVE, '1 - Enable custom gestures animations. 0 - disables.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_tactical_groups', bgNPC.cvar.bgn_module_tactical_groups,
	FCVAR_ARCHIVE, '1 - Enable tactical groups. 0 - disables.')
	.Access(DefaultAccess)

scvar.Register('bgn_module_followers_mod_addon', bgNPC.cvar.bgn_module_followers_mod_addon,
	FCVAR_ARCHIVE, '1 - Enable sopport addon "Followers Mod". 0 - disables.')
	.Access(DefaultAccess)

scvar.Register('bgn_all_models_random', bgNPC.cvar.bgn_all_models_random,
	FCVAR_ARCHIVE, '1 - makes any NPCs with random models from the list. 0 - disables.')
	.Access(DefaultAccess)

scvar.Register('bgn_runtime_generator_grid_offset', bgNPC.cvar.bgn_runtime_generator_grid_offset,
	FCVAR_ARCHIVE, 'Offset between points for grid generation')
	.Access(DefaultAccess)

for npcType, v in pairs(bgNPC.cfg.actors) do
	local enabled = 0
	if v.enabled then enabled = 1 end

	scvar.Register('bgn_npc_type_' .. npcType, enabled, FCVAR_ARCHIVE)
		.Access(DefaultAccess)
end

for npcType, v in pairs(bgNPC.cfg.actors) do
	scvar.Register('bgn_npc_type_max_' .. npcType, bgNPC:GetFullness(npcType), FCVAR_ARCHIVE)
		.Access(DefaultAccess)
end

for npcType, v in pairs(bgNPC.cfg.actors) do
	scvar.Register('bgn_disable_weapon_' .. npcType , 0, FCVAR_ARCHIVE)
		.Access(DefaultAccess)
end

for npcType, v in pairs(bgNPC.cfg.actors) do
	local max_vehicle = v.max_vehicle or 0
	scvar.Register('bgn_npc_vehicle_max_' .. npcType, max_vehicle, FCVAR_ARCHIVE)
		.Access(DefaultAccess)
end