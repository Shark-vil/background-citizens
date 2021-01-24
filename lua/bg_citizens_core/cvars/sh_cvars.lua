bgNPC.cvar = bgNPC.cvar or {}
bgNPC.cvar.bgn_enable = 1
bgNPC.cvar.bgn_max_npc = 35
bgNPC.cvar.bgn_spawn_radius = 3000
bgNPC.cvar.bgn_spawn_radius_visibility = 2500
bgNPC.cvar.bgn_spawn_radius_raytracing = 2000
bgNPC.cvar.bgn_spawn_block_radius = 600
bgNPC.cvar.bgn_spawn_period = 1
bgNPC.cvar.bgn_ptp_distance_limit = 500
bgNPC.cvar.bgn_point_z_limit = 100
bgNPC.cvar.bgn_enable_wanted_mode = 1
bgNPC.cvar.bgn_wanted_time = 30
bgNPC.cvar.bgn_wanted_level = 1
bgNPC.cvar.bgn_wanted_hud_text = 1
bgNPC.cvar.bgn_wanted_hud_stars = 1
bgNPC.cvar.bgn_arrest_mode = 0
bgNPC.cvar.bgn_arrest_time = 5
bgNPC.cvar.bgn_arrest_time_limit = 20
bgNPC.cvar.bgn_ignore_another_npc = 0

function bgNPC:IsActiveNPCType(type)
	return GetConVar('bgn_npc_type_' .. type):GetBool()
end