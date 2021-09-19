CreateConVar('bgn_cl_draw_npc_path', bgNPC.cvar.bgn_cl_draw_npc_path,
{ FCVAR_ARCHIVE }, 'Draw the path of movement of the NPC.')

CreateConVar('bgn_cl_field_view_optimization', bgNPC.cvar.bgn_cl_field_view_optimization,
{ FCVAR_ARCHIVE }, 'Enable field of view optimization.')

CreateConVar('bgn_cl_field_view_optimization_range', bgNPC.cvar.bgn_cl_field_view_optimization_range,
{ FCVAR_ARCHIVE }, 'The minimum distance in which the check is not performed.')

CreateConVar('bgn_cl_ambient_sound', bgNPC.cvar.bgn_cl_ambient_sound,
{ FCVAR_ARCHIVE }, 'Plays a crowd sound based on the number of actors around you. (WARNING! Not recommended for use on weak PC!)')

CreateConVar('bgn_tool_draw_distance', bgNPC.cvar.bgn_tool_draw_distance,
{ FCVAR_ARCHIVE }, 'Distance to draw points in edit mode.')

CreateConVar('bgn_tool_point_editor_autoparent', bgNPC.cvar.bgn_tool_point_editor_autoparent,
{ FCVAR_ARCHIVE }, 'Enable automatic creation of nodes links.')

CreateConVar('bgn_tool_point_editor_autoalignment', bgNPC.cvar.bgn_tool_point_editor_autoalignment,
{ FCVAR_ARCHIVE }, 'Enable automatic height alignment.')

CreateConVar('bgn_tool_point_editor_show_parents', bgNPC.cvar.bgn_tool_point_editor_show_parents,
{ FCVAR_ARCHIVE }, 'Show global connections.')

CreateConVar('bgn_tool_seat_offset_pos_x', bgNPC.cvar.bgn_tool_seat_offset_pos_x,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_pos_y', bgNPC.cvar.bgn_tool_seat_offset_pos_y,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_pos_z', bgNPC.cvar.bgn_tool_seat_offset_pos_z,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_angle_x', bgNPC.cvar.bgn_tool_seat_offset_angle_x,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_angle_y', bgNPC.cvar.bgn_tool_seat_offset_angle_y,
{ FCVAR_ARCHIVE }, '')

CreateConVar('bgn_tool_seat_offset_angle_z', bgNPC.cvar.bgn_tool_seat_offset_angle_z,
{ FCVAR_ARCHIVE }, '')

concommand.Add('bgn_reset_cvars_to_factory_settings', function(ply, cmd, args)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

	RunConsoleCommand('bgn_enable', bgNPC.cvar.bgn_enable)
	RunConsoleCommand('bgn_debug', bgNPC.cvar.bgn_debug)
	RunConsoleCommand('bgn_max_npc', bgNPC.cvar.bgn_max_npc)
	RunConsoleCommand('bgn_spawn_radius', bgNPC.cvar.bgn_spawn_radius)
	RunConsoleCommand('bgn_disable_logic_radius', bgNPC.cvar.bgn_disable_logic_radius)
	RunConsoleCommand('bgn_spawn_radius_visibility', bgNPC.cvar.bgn_spawn_radius_visibility)
	RunConsoleCommand('bgn_spawn_radius_raytracing', bgNPC.cvar.bgn_spawn_radius_raytracing)
	RunConsoleCommand('bgn_spawn_block_radius', bgNPC.cvar.bgn_spawn_block_radius)
	RunConsoleCommand('bgn_spawn_period', bgNPC.cvar.bgn_spawn_period)
	-- RunConsoleCommand('bgn_ptp_distance_limit', bgNPC.cvar.bgn_ptp_distance_limit)
	RunConsoleCommand('bgn_point_z_limit', bgNPC.cvar.bgn_point_z_limit)
	RunConsoleCommand('bgn_enable_wanted_mode', bgNPC.cvar.bgn_enable_wanted_mode)
	RunConsoleCommand('bgn_wanted_time', bgNPC.cvar.bgn_wanted_time)
	RunConsoleCommand('bgn_wanted_level', bgNPC.cvar.bgn_wanted_level)
	RunConsoleCommand('bgn_wanted_hud_text', bgNPC.cvar.bgn_wanted_hud_text)
	RunConsoleCommand('bgn_wanted_hud_stars', bgNPC.cvar.bgn_wanted_hud_stars)
	RunConsoleCommand('bgn_arrest_mode', bgNPC.cvar.bgn_arrest_mode)
	RunConsoleCommand('bgn_arrest_time', bgNPC.cvar.bgn_arrest_time)
	RunConsoleCommand('bgn_arrest_time_limit', bgNPC.cvar.bgn_arrest_time_limit)
	RunConsoleCommand('bgn_ignore_another_npc', bgNPC.cvar.bgn_ignore_another_npc)
	RunConsoleCommand('bgn_shot_sound_mode', bgNPC.cvar.bgn_shot_sound_mode)
	RunConsoleCommand('bgn_cl_field_view_optimization', bgNPC.cvar.bgn_cl_field_view_optimization)
	RunConsoleCommand('bgn_cl_field_view_optimization_range', bgNPC.cvar.bgn_cl_field_view_optimization_range)
	RunConsoleCommand('bgn_cl_ambient_sound', bgNPC.cvar.bgn_cl_ambient_sound)
	RunConsoleCommand('bgn_disable_citizens_weapons', bgNPC.cvar.bgn_disable_citizens_weapons)
	RunConsoleCommand('bgn_disable_halo', bgNPC.cvar.bgn_disable_halo)
	RunConsoleCommand('bgn_enable_dv_support', bgNPC.cvar.bgn_enable_dv_support)
	RunConsoleCommand('bgn_disable_dialogues', bgNPC.cvar.bgn_disable_dialogues)
	RunConsoleCommand('bgn_movement_checking_parts', bgNPC.cvar.bgn_movement_checking_parts)

	for npcType, v in pairs(bgNPC.cfg.npcs_template) do
		RunConsoleCommand('bgn_npc_type_' .. npcType, 1)
	end

	for npcType, v in pairs(bgNPC.cfg.npcs_template) do
		RunConsoleCommand('bgn_npc_type_max_' .. npcType, bgNPC:GetFullness(npcType))
	end
end)

local is_first_bgn_enable = false
cvars.AddChangeCallback('bgn_enable', function(cvar_name, old_value, new_value)
	if is_first_bgn_enable or tonumber(new_value) ~= 1 then return end
	is_first_bgn_enable = true

	LocalPlayer():slibNotify('The first launch of "Background NPCs" can cause lags. '
	.. 'Please wait until the end of the spawn.', NOTIFY_HINT, 10)
end)