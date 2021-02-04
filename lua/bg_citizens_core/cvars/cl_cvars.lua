CreateConVar('bgn_cl_field_view_optimization', bgNPC.cvar.bgn_cl_field_view_optimization, 
{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, 
'Enable field of view optimization.')

CreateConVar('bgn_cl_field_view_optimization_range', bgNPC.cvar.bgn_cl_field_view_optimization_range, 
{ FCVAR_ARCHIVE, FCVAR_NOTIFY }, 
'The minimum distance in which the check is not performed.')

concommand.Add('bgn_reset_cvars_to_factory_settings', function(ply, cmd, args)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

	RunConsoleCommand('bgn_enable', bgNPC.cvar.bgn_enable)
	RunConsoleCommand('bgn_max_npc', bgNPC.cvar.bgn_max_npc)
	RunConsoleCommand('bgn_spawn_radius', bgNPC.cvar.bgn_spawn_radius)
	RunConsoleCommand('bgn_spawn_radius_visibility', bgNPC.cvar.bgn_spawn_radius_visibility)
	RunConsoleCommand('bgn_spawn_radius_raytracing', bgNPC.cvar.bgn_spawn_radius_raytracing)
	RunConsoleCommand('bgn_spawn_block_radius', bgNPC.cvar.bgn_spawn_block_radius)
	RunConsoleCommand('bgn_spawn_period', bgNPC.cvar.bgn_spawn_period)
	RunConsoleCommand('bgn_ptp_distance_limit', bgNPC.cvar.bgn_ptp_distance_limit)
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

	for npcType, v in pairs(bgNPC.cfg.npcs_template) do
		RunConsoleCommand('bgn_npc_type_' .. npcType, 1)
	end
end)