--[[-----------------------------------------
	 Spawn settings menu
--]]
return {
	['bgn.settings.spawn.bgn_dynamic_nodes'] = 'Dynamic movement mesh',
	['bgn.settings.spawn.bgn_dynamic_nodes.description'] = 'Description: allows you to generate a movement mesh automatically around the players. This is useful when the map does not have a movement mesh file. Keep in mind that this is a resource intensive process. It is recommended to create a movement mesh yourself, or generate one if the map has AI NavMesh.',
	['bgn.settings.spawn.bgn_dynamic_nodes_restict'] = 'Dynamic movement mesh constraint',
	['bgn.settings.spawn.bgn_dynamic_nodes_restict.description'] = 'Description: if enabled, the mesh will be generated only when there is no movement mesh file on the map. Otherwise, automatic generation will always be used.',
	['bgn.settings.spawn.bgn_dynamic_nodes_type'] = 'Tim dynamic mesh',
	['bgn.settings.spawn.bgn_dynamic_nodes_type.description'] = 'Description:\n' .. 'random - the mesh will be generated randomly. Increases variety, but accuracy is much lower. May not work at all in narrow spaces.\n' .. 'grid - the grid is generated in a staggered uniform pattern over the entire area around the player. Less random, but more likely to fill the area with move points. (Recommended)',
	['bgn.settings.spawn.bgn_spawn_radius'] = 'NPC spawn radius',
	['bgn.settings.spawn.bgn_spawn_radius.description'] = 'Description: NPC spawn radius relative to the player.',
	['bgn.settings.spawn.bgn_spawn_radius_visibility'] = 'Visibility radius',
	['bgn.settings.spawn.bgn_spawn_radius_visibility.description'] = 'Description: NPCs further than this radius will move away or teleport closer to the player. This allows you to create more activity around the players.',
	['bgn.settings.spawn.bgn_spawn_block_radius'] = 'NPC spawn blocking radius relative to each player',
	['bgn.settings.spawn.bgn_spawn_block_radius.description'] = 'Description: prohibits spawning NPCs within a given radius. 0 - Disable checker',
	['bgn.settings.spawn.bgn_spawn_period'] = 'The period between spawning NPCs (Change requires restart)',
	['bgn.settings.spawn.bgn_spawn_period.description'] = 'Description: sets the delay between spawning of each NPC.',
	['bgn.settings.spawn.bgn_actors_teleporter'] = 'NPC teleportation',
	['bgn.settings.spawn.bgn_actors_teleporter.description'] = 'Description: instead of removing the NPC after losing it from the players field of view, it will teleport to the nearest point. This method is more preferable for optimization because the server does not need to constantly create new entities.',
	['bgn.settings.spawn.bgn_actors_max_teleports'] = 'Maximum NPCs to teleport',
	['bgn.settings.spawn.bgn_actors_max_teleports.description'] = 'Description: how many NPCs can be teleported in one second. The larger the number, the more calculations will be performed. The teleport is calculated for each actor individually, without waiting for the teleport of another actor from his group.',
	['bgn.settings.spawn.bgn_runtime_generator_grid_offset'] = 'Distance between points',
	['bgn.settings.spawn.bgn_runtime_generator_grid_offset.description'] = 'Description: sets the distance between points in the "Grid" mode of the generator. The higher the value, the greater the distance between the points.',
}