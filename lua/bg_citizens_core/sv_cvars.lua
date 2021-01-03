CreateConVar('bg_citizens_enable', 1, FCVAR_ARCHIVE, 'Toggles the modification activity. 1 - enabled, 0 - disabled.')
CreateConVar('bg_citizens_max_npc', 20, FCVAR_ARCHIVE, 'The maximum number of background NPCs on the map.')
CreateConVar('bg_citizens_spawn_radius', 3000, FCVAR_ARCHIVE, 'NPC spawn radius relative to the player.')
CreateConVar('bg_citizens_spawn_radius_visibility', 2500, FCVAR_ARCHIVE, 'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.')
CreateConVar('bg_citizens_spawn_radius_raytracing', 2000, FCVAR_ARCHIVE, 'Checks the spawn points of NPCs using ray tracing in a given radius. This parameter must not be more than - bg_citizens_spawn_radius_visibility. 0 - Disable checker')
CreateConVar('bg_citizens_spawn_block_radius', 800, FCVAR_ARCHIVE, 'Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bg_citizens_spawn_radius_ray_tracing. 0 - Disable checker')
CreateConVar('bg_citizens_spawn_period', 2, FCVAR_ARCHIVE, 'The period between the spawn of the NPC. Changes require a server restart.')
CreateConVar('bg_citizens_tool_limit', 500, FCVAR_ARCHIVE, 'You can change the point-to-point limit for the instrument if you have a navigation mesh on your map.')