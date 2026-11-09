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
| `bgn_save_map` | save the active movement graph to your duplications |

Old route files are converted automatically on load, so map packs made for older versions keep working.
Unversioned routes and versions 1.0–1.2 are supported from `data/citizens_points/` and
`data/background_npcs/nodes/` (`.dat` or `.json`). Loading leaves the original files intact.
Autocomplete for `bgn_convert_legacy_nodes` lists server maps with legacy routes and no new graph yet.
Without an argument, the command converts the current map.

Select a route in the spawn menu's **Duplications** tab to load it on the server and into the point editor.
Old SLibrary `BGN_NODES` duplications work without SLibrary. Save the route from the editor to keep it after
a map restart; loading a duplication does not overwrite the saved route. Saving and loading require admin
rights, and new duplications can only be loaded on their original map.

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
While an actor sits in a police car or an ambulance, players can't get in (locked sound).

## Doors

| Cvar (server) | Default | Meaning |
|---|---|---|
| `bgn_npc_open_doors` | `1` | actors open closed doors on their way; `0`: only open doors are walked through |
| `bgn_npc_open_locked_doors` | `0` | locked doors too: unlocked to open, locked again when closed after 10 s |

Menu: **General → Doors**. `bgNPC.Util.CanActorOpenDoor(door)` checks both, `bgNPC.Util.IsDoorOpen(door)`
tells an open door (`prop_door_rotating`, `func_door*`). Engine NPCs get `CAP_OPEN_DOORS` only while doors are
allowed, NextBots open only the doors allowed; paths route only through doors that are open or may be opened.
An open door is not "opened" again: the opening animation used to stop actors in the doorway.

Doorways: an actor within 90 units of a door doesn't collide with other actors
(`COLLISION_GROUP_NPC_SCRIPTED`, `actor/events/sv_door_pass.lua`), so a crowd going both ways passes instead of
jamming. Players and props still collide; sitting or riding actors keep their group.
