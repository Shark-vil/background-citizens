local bgn_enable = 1
local bgn_max_npc = 20
local bgn_spawn_radius = 3000
local bgn_spawn_radius_visibility = 2500
local bgn_spawn_radius_raytracing = 2000
local bgn_spawn_block_radius = 800
local bgn_spawn_period = 1
local bgn_ptp_distance_limit = 500
local bgn_point_z_limit = 100
local bgn_enable_wanted_mode = 1
local bgn_wanted_time = 30
local bgn_arrest_mode = 0
local bgn_arrest_time = 5
local bgn_arrest_time_limit = 20

function bgNPC:IsActiveNPCType(type)
    return GetConVar('bgn_npc_type_' .. type):GetBool()
end

concommand.Add('bgn_reset_cvars_to_factory_settings', function(ply, cmd, args)
    if IsValid(ply) then
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
    end

    RunConsoleCommand('bgn_enable', bgn_enable)
    RunConsoleCommand('bgn_max_npc', bgn_max_npc)
    RunConsoleCommand('bgn_spawn_radius', bgn_spawn_radius)
    RunConsoleCommand('bgn_spawn_radius_visibility', bgn_spawn_radius_visibility)
    RunConsoleCommand('bgn_spawn_radius_raytracing', bgn_spawn_radius_raytracing)
    RunConsoleCommand('bgn_spawn_block_radius', bgn_spawn_block_radius)
    RunConsoleCommand('bgn_spawn_period', bgn_spawn_period)
    RunConsoleCommand('bgn_ptp_distance_limit', bgn_ptp_distance_limit)
    RunConsoleCommand('bgn_point_z_limit', bgn_point_z_limit)
    RunConsoleCommand('bgn_enable_wanted_mode', bgn_enable_wanted_mode)
    RunConsoleCommand('bgn_wanted_time', bgn_wanted_time)
    RunConsoleCommand('bgn_arrest_mode', bgn_arrest_mode)
    RunConsoleCommand('bgn_arrest_time', bgn_arrest_time)
    RunConsoleCommand('bgn_arrest_time_limit', bgn_arrest_time_limit)

    local exists_types = {}
    for k, v in ipairs(bgNPC.npc_classes) do
        if not table.HasValue(exists_types, v.type) then
            RunConsoleCommand('bgn_npc_type_' .. v.type, 1)
            table.insert(exists_types, v.type)
        end
    end
end)

CreateConVar('bgn_enable', bgn_enable, FCVAR_ARCHIVE, 
'Toggles the modification activity. 1 - enabled, 0 - disabled.')

CreateConVar('bgn_enable_wanted_mode', bgn_enable_wanted_mode, FCVAR_ARCHIVE, 
'Enables or disables wanted mode.')

CreateConVar('bgn_wanted_time', bgn_wanted_time, FCVAR_ARCHIVE, 
'The time you need to go through to remove the wanted level.')

CreateConVar('bgn_max_npc', bgn_max_npc, FCVAR_ARCHIVE, 
'The maximum number of background NPCs on the map.')

CreateConVar('bgn_spawn_radius', bgn_spawn_radius, FCVAR_ARCHIVE, 
'NPC spawn radius relative to the player.')

CreateConVar('bgn_spawn_radius_visibility', bgn_spawn_radius_visibility, FCVAR_ARCHIVE, 
'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.')

CreateConVar('bgn_spawn_radius_raytracing', bgn_spawn_radius_raytracing, FCVAR_ARCHIVE, 
'Checks the spawn points of NPCs using ray tracing in a given radius. This parameter must not be more than - bgn_spawn_radius_visibility. 0 - Disable checker')

CreateConVar('bgn_spawn_block_radius', bgn_spawn_block_radius, FCVAR_ARCHIVE, 
'Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker')

CreateConVar('bgn_spawn_period', bgn_spawn_period, FCVAR_ARCHIVE, 
'The period between the spawn of the NPC. Changes require a server restart.')

CreateConVar('bgn_ptp_distance_limit', bgn_ptp_distance_limit, FCVAR_ARCHIVE, 
'You can change the point-to-point limit for the instrument if you have a navigation mesh on your map.')

CreateConVar('bgn_point_z_limit', bgn_point_z_limit, FCVAR_ARCHIVE, 
'Height limit between points. Used to correctly define child points.')

CreateConVar('bgn_arrest_mode', bgn_arrest_mode, FCVAR_ARCHIVE, 
'Includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.')

CreateConVar('bgn_arrest_time', bgn_arrest_time, FCVAR_ARCHIVE, 
'Sets the time allotted for your detention.')

CreateConVar('bgn_arrest_time_limit', bgn_arrest_time_limit, FCVAR_ARCHIVE, 
'Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.')

local exists_types = {}
for k, v in ipairs(bgNPC.npc_classes) do
    if not table.HasValue(exists_types, v.type) then
        CreateConVar('bgn_npc_type_' .. v.type, 1, FCVAR_ARCHIVE)
        table.insert(exists_types, v.type)
    end
end