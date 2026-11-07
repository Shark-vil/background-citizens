# Navigation

Actors move with the help of one **navigation provider**, chosen per map (`bgNPC.Nav`, server only).

| Provider | Data | Used when |
|---|---|---|
| `custom` | own node graph, `data/background_npcs/graph/<map>.dat` | a route file (or an old route file) exists for the map |
| `navmesh` | the map's NavMesh | the map ships a NavMesh |
| `nodegraph` | the map's `maps/graphs/<map>.ain` | no NavMesh, but the map has an HL2 node graph |
| `custom` (empty) | generated at runtime | none of the above |

The addon never starts the engine's NavMesh generation.

## Console

| Command / cvar | Meaning |
|---|---|
| `bgn_nav_provider auto\|navmesh\|nodegraph\|custom` | force a provider (`auto` by default) |
| `bgn_nav_info` | print the active provider and its size |
| `bgn_nav_reload` | reload navigation data |
| `bgn_nav_generate` | generate nodes over the whole map (flood fill from spawn points and players) |
| `bgn_nav_generate around [radius]` | generate only around you |
| `bgn_nav_generate stop` | stop the generator |
| `bgn_nav_generator_max_nodes` | node limit of the generator (15000) |
| `bgn_dynamic_nodes 1` | keep generating around players on maps without saved data |
| `bgn_convert_legacy_nodes [map]` | convert an old route file (`background_npcs/nodes/<map>.dat`) to the new format |
| `bgn_compile` | pack route, seats and Decent Vehicle waypoints into a Lua file for the Workshop |

Old route files are converted automatically on load, so map packs made for older versions keep working.

## Editing routes

The **Point editor** tool edits the custom graph: create points, link them ("walk" links), remove them,
then save with the panel button (`cl_citizens_save_route`). The **Path finder** tool shows the path an actor
would take between two points.

## API (server)

```lua
bgNPC.Points.Count()
bgNPC.Points.GetInRadius(center, radius, link_type)   -- point objects with :GetPos()
bgNPC.Points.GetRandom(center, radius, link_type)
bgNPC.Points.FindPath(start_pos, end_pos, nil, link_type, actor) -- list of Vector, never empty
bgNPC.Nav.GetProvider()   -- the active provider
bgNPC.Nav.GetInfo()       -- { provider, points, links, source }
```

`bgNPC.NodeGraph` is the graph class behind the custom provider (spatial hash, typed links, A*).

## Hooks

| Hook | Realm | Arguments |
|---|---|---|
| `BGN_NavProviderChanged` | server | provider |
| `BGN_NavGeneratorFinished` | server | graph, added_count |
| `BGN_NavEditorGraphLoaded` | client | graph |
| `BGN_PreLoadRoutes`, `BGN_PostLoadRoutes` | server | **OUTDATED**, still called |
| `BGN_LoadingClientRoutes` | client | **OUTDATED**, still called |

## Emergency cars (Decent Vehicle)

Police cars (`npc_dvbgn_police`) chasing an enemy, and ambulances sent to a body (`actor.drive_target_pos`),
ignore traffic rules: siren on, no stopping at red lights or giving way. The route is the shortest one over
the DV waypoints taken in both directions, with jumps to waypoints within 600 units in sight (lane changes,
the opposite side of the road). When the target is in plain sight the car drives straight at it.
Paths are refreshed every 3 s, every 1 s within 1000 units of the target.
