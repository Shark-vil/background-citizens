function bgNPC:IsActiveNPCType(type)
	return GetConVar('bgn_npc_type_' .. type):GetBool()
end

local convars = {
	{
		name = 'bgn_enable',
		description = 'Toggles the modification activity. 1 - enabled, 0 - disabled.',
		type = 'number'
	},

	{
		name = 'bgn_enable_wanted_mode',
		description = 'Enables or disables wanted mode.',
		type = 'number'
	},

	{
		name = 'bgn_wanted_time',
		description = 'The time you need to go through to remove the wanted level.',
		type = 'float'
	},

	{
		name = 'bgn_max_npc',
		description = 'The maximum number of background NPCs on the map.',
		type = 'number'
	},

	{
		name = 'bgn_spawn_radius',
		description = 'NPC spawn radius relative to the player.',
		type = 'float'
	},

	{
		name = 'bgn_spawn_radius_visibility',
		description = 'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.',
		type = 'float'
	},

	{
		name = 'bgn_spawn_radius_raytracing',
		description = 'Checks the spawn points of NPCs using ray tracing in a given radius. This parameter must not be more than - bgn_spawn_radius_visibility. 0 - Disable checker',
		type = 'float',
	},

	{
		name = 'bgn_spawn_block_radius',
		description = 'Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker',
		type = 'float'
	},

	{
		name = 'bgn_spawn_period',
		description = 'The period between the spawn of the NPC. Changes require a server restart.',
		type = 'float'
	},

	{
		name = 'bgn_ptp_distance_limit',
		description = 'You can change the point-to-point limit for the instrument if you have a navigation mesh on your map.',
		type = 'float'
	},

	{
		name = 'bgn_point_z_limit',
		description = 'Height limit between points. Used to correctly define child points.',
		type = 'float'
	},

	{
		name = 'bgn_arrest_mode',
		description = 'Includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.'
	},

	{
		name = 'bgn_arrest_time',
		description = 'Sets the time allotted for your detention.',
		type = 'float'
	},

	{
		name = 'bgn_arrest_time_limit',
		description = 'Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.',
		type = 'float'
	},

	{
		name = 'bgn_ignore_another_npc',
		description = 'If this parameter is active, then NPCs will ignore any other spawned NPCs.',
		type = 'float'
	},
}

for _, v in ipairs(convars) do
	CreateConVar(v.name, bgNPC.cvar[v.name], FCVAR_ARCHIVE, v.description)
end


local exists_types = {}

for k, v in ipairs(bgNPC.npc_classes) do
	if table.HasValue(exists_types, v.type) then continue end

	CreateConVar('bgn_npc_type_' .. v.type, 1, FCVAR_ARCHIVE)
	table.insert(exists_types, v.type)

	bgNPC:RegisterGlobalCvar('bgn_npc_type_' .. v.type, GetConVar('bgn_npc_type_' .. v.type):GetInt())
end

for _, v in ipairs(convars) do
	if not v.type then return end

	if v.type == 'number' then
		bgNPC:RegisterGlobalCvar(v.name, GetConVar(v.name):GetInt())
	elseif v.type == 'float' then
		bgNPC:RegisterGlobalCvar(v.name, GetConVar(v.name):GetFloat())
	end
	-- and next
end