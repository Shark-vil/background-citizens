bgNPC.cvar = bgNPC.cvar or {}
bgNPC.cvar.bgn_enable = 1
bgNPC.cvar.bgn_debug = 0
bgNPC.cvar.bgn_max_npc = 35
bgNPC.cvar.bgn_spawn_radius = 3000
bgNPC.cvar.bgn_disable_logic_radius = 500
bgNPC.cvar.bgn_spawn_radius_visibility = 2500
bgNPC.cvar.bgn_spawn_radius_raytracing = 2000
bgNPC.cvar.bgn_spawn_block_radius = 600
bgNPC.cvar.bgn_spawn_period = 1
-- bgNPC.cvar.bgn_ptp_distance_limit = 500
bgNPC.cvar.bgn_tool_point_editor_autoparent = 1
bgNPC.cvar.bgn_tool_point_editor_autoalignment= 1
bgNPC.cvar.bgn_point_z_limit = 100
bgNPC.cvar.bgn_enable_wanted_mode = 1
bgNPC.cvar.bgn_wanted_time = 30
bgNPC.cvar.bgn_wanted_level = 1
bgNPC.cvar.bgn_wanted_hud_text = 1
bgNPC.cvar.bgn_wanted_hud_stars = 1
bgNPC.cvar.bgn_arrest_mode = 1
bgNPC.cvar.bgn_arrest_time = 5
bgNPC.cvar.bgn_arrest_time_limit = 20
bgNPC.cvar.bgn_ignore_another_npc = 0
bgNPC.cvar.bgn_shot_sound_mode = 0
bgNPC.cvar.bgn_disable_citizens_weapons = 0
bgNPC.cvar.bgn_disable_halo = 0
bgNPC.cvar.bgn_enable_dv_support = 1
bgNPC.cvar.bgn_disable_dialogues = 0
bgNPC.cvar.bgn_tool_draw_distance = 1000
bgNPC.cvar.bgn_movement_checking_parts = 5
bgNPC.cvar.bgn_tool_point_editor_show_parents = 1
bgNPC.cvar.bgn_actors_teleporter = 0

if CLIENT then
	bgNPC.cvar.bgn_cl_field_view_optimization = 0
	bgNPC.cvar.bgn_cl_field_view_optimization_range = 500
	bgNPC.cvar.bgn_cl_ambient_sound = 0
end

function bgNPC:IsActiveNPCType(type)
	return GetConVar('bgn_npc_type_' .. type):GetBool()
end

function bgNPC:GetFullness(type)
	local data = bgNPC.cfg.npcs_template[type]
	if data == nil or not bgNPC:IsActiveNPCType(type) then
		return 0
	end

	if data.fullness ~= nil then
		local max = math.Round(((data.fullness / 100) * GetConVar('bgn_max_npc'):GetInt()))
		if max >= 0 then return max end
	elseif data.limit ~= nil then
		return math.Round(data.limit)
	end

	return 0
end

function bgNPC:GetLimitActors(type)
	return GetConVar('bgn_npc_type_max_' .. type):GetInt()
end

CreateConVar("bgn_installed", 1, {
	FCVAR_ARCHIVE,
	FCVAR_NOTIFY,
	FCVAR_REPLICATED,
	FCVAR_SERVER_CAN_EXECUTE
}, "")

slib:RegisterGlobalCvar('bgn_enable', bgNPC.cvar.bgn_enable, 
FCVAR_ARCHIVE, 'Toggles the modification activity. 1 - enabled, 0 - disabled.')

slib:RegisterGlobalCvar('bgn_debug', bgNPC.cvar.bgn_debug, 
FCVAR_ARCHIVE, 'Turns on debug mode and prints additional information to the console.')

slib:RegisterGlobalCvar('bgn_enable_wanted_mode', bgNPC.cvar.bgn_enable_wanted_mode,
FCVAR_ARCHIVE, 'Enables or disables wanted mode.')

slib:RegisterGlobalCvar('bgn_wanted_time', bgNPC.cvar.bgn_wanted_time, 
FCVAR_ARCHIVE, 'The time you need to go through to remove the wanted level.')

slib:RegisterGlobalCvar('bgn_wanted_level', bgNPC.cvar.bgn_wanted_level, 
FCVAR_ARCHIVE, 'Enables or disables the boost wanted level mode.')

slib:RegisterGlobalCvar('bgn_wanted_hud_text', bgNPC.cvar.bgn_wanted_hud_text, 
FCVAR_ARCHIVE, 'Enables or disables the text about wanted time.')

slib:RegisterGlobalCvar('bgn_wanted_hud_stars', bgNPC.cvar.bgn_wanted_hud_stars, 
FCVAR_ARCHIVE, 'Enables or disables drawing of stars in wanted mode.')

slib:RegisterGlobalCvar('bgn_max_npc', bgNPC.cvar.bgn_max_npc, 
FCVAR_ARCHIVE, 'The maximum number of background NPCs on the map.')

slib:RegisterGlobalCvar('bgn_spawn_radius', bgNPC.cvar.bgn_spawn_radius, 
FCVAR_ARCHIVE, 'NPC spawn radius relative to the player.')

slib:RegisterGlobalCvar('bgn_disable_logic_radius', bgNPC.cvar.bgn_disable_logic_radius, 
FCVAR_ARCHIVE, 'Determines at what distance the NPC will disable logic for optimization purposes')

slib:RegisterGlobalCvar('bgn_spawn_radius_visibility', bgNPC.cvar.bgn_spawn_radius_visibility, 
FCVAR_ARCHIVE, 'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.')

slib:RegisterGlobalCvar('bgn_spawn_radius_raytracing', bgNPC.cvar.bgn_spawn_radius_raytracing, 
FCVAR_ARCHIVE, 'Checks the spawn points of NPCs using ray tracing in a given radius. This parameter must not be more than - bgn_spawn_radius_visibility. 0 - Disable checker')

slib:RegisterGlobalCvar('bgn_spawn_block_radius', bgNPC.cvar.bgn_spawn_block_radius, 
FCVAR_ARCHIVE, 'Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker')

slib:RegisterGlobalCvar('bgn_spawn_period', bgNPC.cvar.bgn_spawn_period, 
FCVAR_ARCHIVE, 'The period between the spawn of the NPC. Changes require a server restart.')

-- slib:RegisterGlobalCvar('bgn_ptp_distance_limit', bgNPC.cvar.bgn_ptp_distance_limit, 
-- FCVAR_ARCHIVE, 'You can change the point-to-point limit for the instrument if you have a navigation mesh on your map.')

slib:RegisterGlobalCvar('bgn_point_z_limit', bgNPC.cvar.bgn_point_z_limit, 
FCVAR_ARCHIVE, 'Height limit between points. Used to correctly define child points.')

slib:RegisterGlobalCvar('bgn_arrest_mode', bgNPC.cvar.bgn_arrest_mode, 
FCVAR_ARCHIVE, 'Includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.')

slib:RegisterGlobalCvar('bgn_arrest_time', bgNPC.cvar.bgn_arrest_time, 
FCVAR_ARCHIVE, 'Sets the time allotted for your detention.')

slib:RegisterGlobalCvar('bgn_arrest_time_limit', bgNPC.cvar.bgn_arrest_time_limit, 
FCVAR_ARCHIVE, 'Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.')

slib:RegisterGlobalCvar('bgn_ignore_another_npc', bgNPC.cvar.bgn_ignore_another_npc, 
FCVAR_ARCHIVE, 'If this parameter is active, then NPCs will ignore any other spawned NPCs.')

slib:RegisterGlobalCvar('bgn_shot_sound_mode', bgNPC.cvar.bgn_shot_sound_mode, 
FCVAR_ARCHIVE, 'If enabled, then NPCs will react to the sound of a shot as if someone was shooting at an ally. (Warning: this function is experimental and not recommended for use)')

slib:RegisterGlobalCvar('bgn_disable_citizens_weapons', bgNPC.cvar.bgn_disable_citizens_weapons, 
FCVAR_ARCHIVE, 'Prohibits citizens from having weapons.')

slib:RegisterGlobalCvar('bgn_disable_halo', bgNPC.cvar.bgn_disable_halo, 
FCVAR_ARCHIVE, 'Disable NPC highlighting stroke.')

slib:RegisterGlobalCvar('bgn_enable_dv_support', bgNPC.cvar.bgn_enable_dv_support, 
FCVAR_ARCHIVE, 'Includes compatibility with the "DV" addon and forces NPCs to use vehicles.')

slib:RegisterGlobalCvar('bgn_disable_dialogues', bgNPC.cvar.bgn_disable_dialogues, 
FCVAR_ARCHIVE, 'Activate this if you want to disable dialogues between NPCs.')

slib:RegisterGlobalCvar('bgn_movement_checking_parts', bgNPC.cvar.bgn_movement_checking_parts, 
FCVAR_ARCHIVE, 'The number of NPCs whose movement can be checked at one time. The higher the number, the less frames you get, but NPCs will stop less often, waiting for the command to move to the next point. Recommended for weak PCs - 1, for medium - 5, for powerful - 10.')

slib:RegisterGlobalCvar('bgn_actors_teleporter', bgNPC.cvar.bgn_actors_teleporter, 
FCVAR_ARCHIVE, 'Instead of removing the NPC after losing it from the players field of view, it will teleport to the nearest point. This will create the effect of a more populated city. Disable this option if you notice dropped frames.')

for npcType, v in pairs(bgNPC.cfg.npcs_template) do
	slib:RegisterGlobalCvar('bgn_npc_type_' .. npcType, (v.enabled or 1), FCVAR_ARCHIVE)
end

for npcType, v in pairs(bgNPC.cfg.npcs_template) do
	slib:RegisterGlobalCvar('bgn_npc_type_max_' .. npcType, bgNPC:GetFullness(npcType), 
		FCVAR_ARCHIVE)
end