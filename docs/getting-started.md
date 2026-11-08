# Quick start

1. Subscribe to [Background NPCs on Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=2341497926), or put this repository in `garrysmod/addons/background-citizens`. Avoid installing two copies.
2. Start a map, for example `gm_construct`. Version 2.0 does not require SLibrary.
3. Open the developer console and run `bgn_menu`. You can also use the Background NPCs icon in the C menu.
4. On first launch choose Classic or New, then follow the setup wizard. Classic uses engine NPCs and FSM; New selects bodies and brains automatically and enables the ghost crowd.
5. Walk around and allow time for spawning. Actors generally appear outside your view; the limit is not an immediate spawn command.

Server settings require admin rights. Voice and interface choices are local to each player.

## Reopen setup

```text
bgn_mode_welcome
bgn_wizard
```

`bgn_wizard all` includes advanced steps. Changes in the wizard apply immediately; closing it does not undo them.

## Vehicles are optional

Install [Decent Vehicle](https://steamcommunity.com/sharedfiles/filedetails/?id=1587455087), vehicle models referenced by your actor configuration, and suitable DV waypoints for the map. Pedestrian routes and DV waypoints are separate.

## Check navigation

Run `bgn_nav_info` in the server console (or as an admin). The addon can use custom routes, a NavMesh or an HL2 nodegraph. See [navigation](systems/navigation.md) before generating new routes; engine `nav_generate` is not required by the addon.
