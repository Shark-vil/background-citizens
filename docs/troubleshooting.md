# Troubleshooting

| Symptom | Check |
| --- | --- |
| No actors | Open `bgn_menu`, enable actor types and give them nonzero limits. Walk around and run `bgn_nav_info` on the server. |
| No navigation points | Try `bgn_nav_generate around 1500`, then `bgn_nav_info`. This uses the addon's point generator. `bgn_nav_generate` covers the map; `bgn_nav_generate stop` cancels it. See [navigation](systems/navigation.md). |
| Server settings missing or won't change | They require admin rights and are hidden from ordinary players. Run `bgn_test_settings`: it shows what the server thinks of your group. |
| Custom module not loading | Check `lua/background_npcs_core/custom_modules/config/`, the `sh_` prefix and Lua errors in the console. Restart after creating a new addon directory. |
| Old models or reactions remain | `EditActor` merges tables. Replace the field directly, as in the [examples](examples.md). |
| No cars | Check Decent Vehicle, installed models listed in `vehicles`, a nonzero `max_vehicle` and DV waypoints. Pedestrian points do not replace DV routes. |
| No voices | Check `bgn_cl_voices 1`, voice language and installed sound files. Mode `2` uses only old Half-Life 2 sounds. |
| Low FPS | Start with `bgn_crowd_density low` in single player. High ghost counts cost client FPS too; see [ghost crowd](systems/ghost-crowd.md). |

When reporting a bug, run the [testing mode](systems/testing.md) (`bgn_test`) and attach the copied log. If that is not enough, include the map, gamemode, `bgn_nav_info` output, Lua errors and reproduction steps. Built-in checks: `bgn_selftest` on the server and `bgn_selftest_cl` on the client; these do not replace testing behaviour in game.
