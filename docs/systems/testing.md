# Testing mode

A one-minute check that answers "nothing spawns" and "I'm an admin but can't change the settings" with facts.
Open **Settings → Tools → Testing** (admins) or type a console command:

| Command | Who | What it does |
|---|---|---|
| `bgn_test` | admins | The full test (below). |
| `bgn_test_settings` | anyone | Only the rights and settings checks. Run it first when settings won't change. |
| `bgn_test_report` | anyone | Opens the results of the last test again. |
| `bgn_test_stop` | the player who started it, admins | Stops a running test. |

## What the full test checks

| Check | How |
|---|---|
| Addon and map | `bgn_enable`, navigation provider and points. |
| Admin rights | What the server and the client think of your group (`IsAdmin`, `IsSuperAdmin`, user group). |
| Changing server settings | The client sets the test cvar `bgn_test_server_value` the same way every settings row does, the server must receive it; then the server changes it itself and the client must see it. |
| Changing client settings | The test cvar `bgn_cl_test_value` is set and read back. |
| Actors spawn on their own | Actors exist or the regular spawner creates one within 15 s. If not, the most likely reason is named: addon off, zero limits, no navigation points, no spot out of sight, other addon. |
| Actors spawn on demand | One actor of each active type is created at free spots around you, ignoring limits and visibility rules. Wanted-only types are skipped. |
| Cars | Decent Vehicle is loaded, the map has its waypoints, the configured car models are installed; a driver is spawned with a car and has to get in. Missing Decent Vehicle is a warning, not an error. |
| Actors don't vanish | The spawned actors and cars must still exist 12 s later. An actor spawned over its type limit is expected to be removed (the log says so). |
| Actor states | Every actor has a valid entity and a known state, stands inside the world, walkers really move, and a forced `idle` / `walk` change is accepted. |
| Where the actors are | Actors closer than 700 units form a group. The camera flies over the four biggest ones, outlining the actors and marking the spot with a beam and a sphere. **Space** skips it. You are frozen and invulnerable meanwhile. |

Test actors and cars are removed at the end, the changed cvars are restored.

## The Fix button

Where the cause is obvious and the cure is a setting, an admin sees **Fix** on the row: the addon switched off, a zero total limit, all actor types off, a spawn radius with no points in it, block and visibility radii that leave no free spot, car support off. It restores the default values of just those console variables (the log lists them) and asks to run the test again. Rights, missing addons and maps without navigation have no button: they can't be fixed from a setting.

## Results window

It has the settings window's look, the same light / dark switch, and one row per check with an icon (passed,
warning, failed) and a short plain sentence. **Copy log** puts the full technical report into the clipboard
(it is also saved to `data/background_npcs/test_report.txt`); the server console prints it too. Paste it into
a bug report. The sentences follow the interface language; the log is always English.

```
================================================================
 Background NPCs - test report
================================================================
 Version  : 2.0.1
 Map      : gm_construct
 Server   : listen server, 2 player(s)
 Result   : 8 passed, 1 warnings, 1 failed
================================================================

[FAIL] Admin rights
       The server does not see you as an admin (your group: user). ...
       | server: IsAdmin=false IsSuperAdmin=false group="user" listen host=false
       | client: IsAdmin=false IsSuperAdmin=false group="user"
```

## Notes

- In single player and on a listen server the client and the server share console variables, so the server
  settings check can pass without admin rights; it then ends with a warning. Run it on the real server.
- Only admins can run the full test; for others `bgn_test` runs the settings checks only.
- The two test cvars are also sliders in **Tools → Testing**: change them by hand to see what a normal row does.
- Source: `lua/background_npcs_core/debug/` (`sv_diag.lua` runs the checks, `cl_diag.lua` is the camera and
  the window). A check is a function that calls `Section(id)`, `Log(...)` and `Result(status, phrase, ...)`;
  phrases live in `resource/localization/<lang>/bgn_diag.properties`.

## DV traffic developer checks

Only BGN-created vehicles (`isBgnVehicle`) use the new recovery controller; the original DV remains a dependency. Police designation (`bgnPoliceVehicle`) persists across driver/group changes. Only actors on team `police` can drive or ride in these cars. Players may still take an empty police car.

Pedestrians keep their detour side and intermediate goals. The 30% chance of ignoring road caution does not disable navigation around solid obstacles. Local traffic scans run at most twice per second, excluding dormant actors.

Stalled drivers wait and honk before planning a bounded forward/reverse maneuver, including the opposite lane or sidewalk when space and ground support permit. Planning uses the shared task budget; control updates remain frequent. Red lights, scheduled stops and taxi passenger waits suppress recovery. Impossible maneuvers fall back to waiting and existing unseen-vehicle cleanup (`bgn_vehicle_cleanup_time`, default 120 seconds).

The `tools/dv_*.lua` fixtures use a temporary single-player file bridge on `gm_bigcity_improved`. The bridge is not shipped as an addon autorun. `python tools/dv_lab.py server <fixture.lua>` sends a fixture to the running game. Reports go to `garrysmod/data/bgn_dv_lab/`.

Fixtures cover police access (`dv_stage1`), chassis/axle alignment (`dv_headings`), NPC/NextBot detours (`dv_stage2`), blockers/turns and original-DV comparison (`dv_stage3`), scheduled-stop/no-path guards (`dv_guards`), two-way traffic (`dv_duel`), and stationary 10/30/60-car sensor benchmarks (`dv_benchmark`). Run one fixture at a time in a test session: they create entities and move the observer. Benchmark `ticks_per_second` measures server ticks, not rendering FPS. Python checks: `python tools/test_regressions.py` (requires lupa).

Local vehicle planning targets mostly level streets. Other axle layouts and steep ramps need separate calibration.
