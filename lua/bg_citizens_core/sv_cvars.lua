CreateConVar('bg_citizens_max_npc', 30, FCVAR_ARCHIVE, 'The maximum number of background NPCs on the map.')
CreateConVar('bg_citizens_spawn_radius', 3000, FCVAR_ARCHIVE, 'NPC spawn radius relative to the player.')
CreateConVar('bg_citizens_spawn_radius_visibility', 2000, FCVAR_ARCHIVE, 'Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.')
CreateConVar('bg_citizens_spawn_radius_ray_tracing', 1000, FCVAR_ARCHIVE, 'Checks the spawn points of NPCs using ray tracing. This parameter must not be more than - bg_citizens_spawn_radius_visibility')