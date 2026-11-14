# Testing mode

## Core engineering audit regressions

`python tools/test_core_audit.py` runs 17 isolated LuaJIT/lupa tests from
`tests/sv_engineering_audit.lua`; SERVER `bgn_selftest` loads the same file on demand without live entities.
The cases cover scheduler mutations, recurring services, mechanics, UID/snapshot reloads, client retirement,
malformed/chunked network input, navigation, GOAP, appearance and gamemode spawn permission/accounting,
regeneration, spawnmenu IO, string UID LOD and client seat downloads. Follow-up cases cover forced exit,
blocked exits and lethal damage without the DV visual, plus wanted observers awaiting a replacement entity.
All 17 fail against the starting `dev`
with `--baseline` and pass after these changes. This models engine calls; it is not a native game result.
See [audit decisions and remaining limits](../core-audit.md).

For interactive scenic and GOAP door checks, use the admin [Scene debugger Tool](scenic.md#scene-debugger-tool).
`tools/scenic_tool.lua` exercises the real server Tool, native Undo, chair cleanup, model diagnostics and the
one-cycle door test on both NPC and NextBot bodies through a temporary single-player bridge. Use an isolated
`gm_bigcity_improved` lab with a NavMesh. Report: `data/bgn_scenic_tool_lab/tool.json`.
Keep actor-remover and scenic maintenance tasks running: the cleanup cases verify that owned tests survive
while an ordinary control actor is removed with `bgn_enable 0`; the fixture restores that setting afterwards.

`tools/door_hold.lua` is an opt-in fixture for an isolated single-player `gm_bigcity_improved` session through
a temporary Lua bridge, not an addon autorun. It tests actual GOAP holding/breaching with all four NPC/NextBot
body pairings and four door headings, physical knockback, stable actor/entity/health, restored door settings,
blocked stand-up, forced-state rejection, holder/ragdoll removal and damage/death while down.
Report: `data/bgn_door_lab/doors.json`.
It creates stock test rigs and doors, briefly moves the observer, pauses automatic spawners and cleans up its
objects/restores tasks and observer afterward. Run it in a lab, not an ongoing play session.
`tools/seating_lab.lua` checks 32 seating cases on both bodies: two stock chair props at four headings,
close and distant approach, BigCity custom bench seats, scenic chairs/benches and both ledge poses on male
and female rigs. It checks direct pelvis support, facing the drop, stable placement and physics/seat restoration
on exit. Run only in an isolated SP lab on port 27025; report: `data/bgn_seat_lab/seating.json`.

Additional opt-in fixtures through the same temporary SP bridge:

| Fixture | Native checks | Report under `data/bgn_scenic_overhaul_lab/` |
|---|---|---|
| `tools/scenic_poses.lua` | NPC/NextBot poses, wall/door contact, indoor rejection, both couch sexes, complete pairs and brush ledges | `poses.json` |
| `tools/carry_items.lua` | Tool/ordinary spawns: HL2 briefcase without a weapon/activity override, NextBot ration/suitcase/newspaper walk, hidden parcel, stowing, drop/expiry | `carry.json` |
| `tools/ghost_carry.lua` | Run SERVER and CLIENT separately: empty hands in both ghost modes and NPC/NextBot materialization without carried items | `ghost-server.json`, `ghost-client.json` |
| `tools/ragdoll_identity.lua` | Same actor/entity, latest health/max health, weapon/clip, incoming/outgoing relationships and wanted record after recovery | `identity.json` |

Fixtures use stock animation rigs for repeatability, clean up their own entities and restore changed settings.
They do not establish support for every custom model or multiplayer behavior. `scenic_poses` uses real BSP
geometry for its ledge test; it does not replace engine traces with stub results.
`tools/carry_alignment.lua` is an opt-in CLIENT render-frame check in an isolated SP lab. It measures the newspaper lower grip against the fingertips, the 15-degree outward tilt and the upright briefcase handle against the index-finger grip. Inspect front and side screenshots for male/female rigs at idle and during actual walking; measurements do not replace the visual check. Reports: `data/bgn_paper_lab/alignment-idle.json` and `alignment-walk.json`.

Offline checks (lupa): `python tools/test_regressions.py`, `python tools/test_scenic.py`, `python tools/test_carry_items.py`.

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

## Actor overlay and regression checks

Debugging is admin-only and requires `bgn_debug 1` (SERVER). CLIENT controls affect only the viewer.
Inspection records existing decisions; it does not run sensors, roll reactions, advance plans or change stealth rules.

### Spawnmenu debug page

Open **Q → Options → Background NPCs → Debugging**, or **Tools → Background NPCs: Debugging → Actor inspector**.
Choose an actor from the refreshed list or under the crosshair. Selection uses the actor UID, including across body
replacement. Pinning prevents the inspector Tool's LMB from replacing it; an explicit menu selection still works.
The default is one actor and its connections. Nearby overview is optional.

**Tools → Background NPCs: Editor** contains route points, spawn areas and seats. **Background NPCs: Debugging**
contains actor inspection, navigation test, actor movement, scenes and carried items. Existing Tool IDs are preserved;
the internal actor spawner remains hidden.

| CLIENT cvar | Default | Meaning |
|---|---|---|
| `bgn_cl_debug_mode` | 0 | 0: screen HUD; 1: world cards (3D2D); 2: geometry only. |
| `bgn_cl_debug_inspector` | 1 | Screen HUD of the selected actor. |
| `bgn_cl_debug_bounds` / `bgn_cl_debug_labels` | 1 / 1 | Bounds / world-card text. |
| `bgn_cl_debug_summary` | 1 | Collection/render CPU time and geometry count in the HUD footer. |
| `bgn_cl_draw_npc_path` | 0 | Selected actor's existing SERVER path. |
| `bgn_cl_debug_targets` | 1 | Known-enemy connections; these are memory, not current visibility. |
| `bgn_cl_debug_vision` | 0 | Recorded gameplay sight checks and blockers. |
| `bgn_cl_debug_signals` / `bgn_cl_debug_history` | 1 / 1 | Team signals / recent events. |
| `bgn_cl_debug_text_scale` | 1 | Text scale 0.75–2; also scales with screen height, 20 px at 900p. |
| `bgn_cl_debug_distance` / `bgn_cl_debug_geometry_distance` | 800 / 1500 | Independent text / geometry limits in HU, each 100–5000. |
| `bgn_cl_debug_wh` / `bgn_cl_debug_overview` | 0 / 0 | Geometry through walls / nearby actor overview. |
| `bgn_cl_debug_related` / `bgn_cl_debug_cards` | 16 / 8 | Relation limit 1–64 per list / visible-card limit 1–16. |
| `bgn_cl_debug_rate` | 5 | Selected snapshot rate, 2–10 Hz. |
| `bgn_cl_debug_seconds` / `bgn_cl_debug_life` | 30 / 2 | History window 1–30 s / line lifetime 0.2–10 s. |
| `bgn_cl_debug_blockers` / `bgn_cl_debug_markers` | 1 / 1 | Sight blockers / scene and hand markers. |
| `bgn_cl_debug_marker_size` | 12 | Marker size 2–48 HU. |
| `bgn_cl_debug_team_filter`, `type_filter`, `state_filter`, `event_filter` | empty | Plain substring filters; all four names have the `bgn_cl_debug_` prefix. Event filter matches the event kind. |
| `bgn_cl_debug_freeze` / `bgn_cl_debug_technical` | 0 / 0 | Freeze diagnostic data / show technical HUD identifiers. |

Less frequent settings are in **Limits and filters**. World cards use distance scaling and overlap suppression;
text wraps, and long reports offer copyable details. List refresh preserves selection and camera.
**Freeze** holds the displayed snapshot, not the game or the live camera.

The compact HUD shows health, state, reaction, known enemies/targets, wanted status, movement, sight and recent events.
**Open details** adds raw state/group, fight avoidance, model/animation, carry item, reaction weights, known-target
last-seen times and the current cached GOAP plan/facts. FSM actors have no GOAP plan.
A weighted reaction pick is a candidate, not proof that a later hook allowed that reaction. Attempted damage is
recorded before cancellation; the reaction event does not establish actual health loss.

Sight comes from the real `HasLineOfSight` / `CanSeeEntity` calls. Channels identify damage witnesses, shot witnesses,
enemy memory, ally sharing, help, wanted detection and squads. Green is a successful check, red a failed check with
its hit point and blocker (including map geometry), purple is remembered enemy knowledge, yellow is a signal.
Rejected signals are red. Absence of a check means unknown. The view cone is drawn only after an actual direction
test, using its recorded aim vector and the same dot-product threshold as `Util.IsInView`; its 100 HU length is
illustrative. Plain LOS has no facing restriction. A remembered enemy can be currently unseen. Wanted proximity
and radio broadcasts do not imply a successful sight trace. No debugger-generated observer ray is added.

Team events identify sender → recipient and the target being discussed. Help, sharing, radio and squad handoffs
record resulting enemy membership; witness-reaction vetoes are recorded separately. The wanted broadcast has no
actor sender. This is a bounded journal of instrumented paths, not a complete log of every rejected AI branch.

SERVER collects selected snapshots at the requested rate and shares collection work for matching subscriptions
within a tick. The actor list is requested on demand (throttled to 1 Hz); overview updates at 2 Hz within 5000 HU.
There is no automatic all-actor stream. Per observed UID: at most 256 events and 64 recent sight records; paths
are capped at 256 points, rosters at 128 actors, and client geometry at 1024 segments. Truncation is reported.
CLIENT builds text and a colored line mesh on snapshot/settings changes, then draws the cached batch each frame;
scene/hand markers refresh at 2 Hz. No per-frame actor search or diagnostic visibility traces are used.
The HUD costs measure collection and client render code, not whole-frame performance or network transmission.

**Toggle actor first-person view** follows the selected actor's eyes. F6, Escape or **Return to your view** exits.
SERVER adds this camera to the admin's PVS and blocks movement/attacks. The player's body remains vulnerable.
Death/removal, viewer death, lost rights, map cleanup, debug disable or lost subscription releases the camera.
Heartbeats are every second, expiry is 3 s, and unfrozen geometry older than 2 s stops drawing. SERVER supplies the
body-relative eye frame for NPCs/NextBots; CLIENT follows body interpolation. Only the viewed body's model
renderer is temporarily suppressed and restored on exit; server `NoDraw` is preserved.

Tool-specific checks:

- `bgn_path_finder`: LMB start, RMB destination, R clear. Uses the active SERVER navigation provider; endpoint
  markers and point count describe this requested path, separately from an actor's current path.
- `bgn_actor_mover`: LMB actor, RMB destination, R/holster release. Walk/run and arrival tolerance are configurable.
  One owner controls the actor; previous debugger/eternal/lock flags and state data are restored on release.
  This Tool deliberately changes movement; it is not passive inspection.
- `bgn_scenic_debug`: existing placement, inspection, GOAP-door test and owned cleanup/Undo remain. The preview
  reuses placement checks, shows participant bounds and rejection reasons, and creates nothing. It uses the
  minimum group layout without RNG; actual spawning may choose another size/orientation/model variant.
- `bgn_carry_debug`: existing give/remove checks remain. Bone axes, prop bounds, model/animation compatibility
  and briefcase handle-to-finger distance help inspect attachment; the number is geometric, not a rig-quality score.
  Both special Tools share distance, WH, marker-size controls and copyable reports.

Console equivalents: `bgn_debug_select [uid]`, `bgn_debug_details`, `bgn_debug_tool_details`, `bgn_debug_watch`,
`bgn_debug_watch_stop`, `bgn_debug_clear`, `bgn_debug_pin`, `bgn_debug_freeze`.

`python tools/test_actor_debug.py` (lupa) checks permission/payload gates, read-only snapshots, bounded history,
map blockers, recorded view direction, camera lifecycle, EN/RU keys and mover restoration. Native single-player
verification on `gm_bigcity_improved` (1280×720, 1600×900, 1920×1080) covers menu categories, real damage/sight/blockers and team handoff,
HUD/3D2D distance, NPC/NextBot camera, refresh/freeze, scene preview/owned removal, carry issuance/removal and cached
mesh construction. Timing samples with 30/60/100 actors cover selected inspection and optional overview; they are
not a general FPS guarantee. Multiplayer and arbitrary camera addons/custom rigs still need separate verification.

`python tools/test_regressions.py` (requires lupa) checks the Lua logic outside GMod. It covers safe actor health accessors in both realms, arrest module registration order, seated damage and police witnesses, passenger aim, exit placement by seat/model attachment, overlap rejection and blocked-side fallback. These checks do not verify live physics or every vehicle model.

## Room siege developer checks

`bgn_selftest` includes `tests/sv_siege.lua`: isolated checks for one-exit pockets, alternative/incoming
connections, outdoor rejection, animation/class requirements, door chance/fallback, shared deployment
reservations, grenade clearance and the wait/cooldown. These do not establish real physics or map completeness.

`tools/siege.lua` is an opt-in SERVER fixture for an isolated single-player `gm_bigcity_improved` session,
using the room near `setpos -748.617798 -4298.178223 -11071.968750`. It creates eight actors and exercises
metropolice/combine operators with NPC and NextBot bodies, including a player target. It checks the double-leaf
exit, missing-animation rejection, five front/three rear participants, silent waiting, one real projectile,
entry into the room, actual damage/attribution against NPC targets, exit/damage cancellation and NPC capability
restoration. It temporarily moves/arms the observer, pauses population
tasks and cleans up/restores its own state. Run it through a temporary local SERVER bridge, never as an autorun
or on a public server. Results: `garrysmod/data/bgn_siege_lab/verification.json`.

## DV traffic developer checks

Only BGN-created vehicles (`isBgnVehicle`) use the new recovery controller; the original DV remains a dependency. Police designation (`bgnPoliceVehicle`) persists across driver/group changes. Only actors on team `police` can drive or ride in these cars. Players may still take an empty police car.

Pedestrians keep their detour side and intermediate goals. The 30% chance of ignoring road caution does not disable navigation around solid obstacles. Local traffic scans run at most twice per second, excluding dormant actors.

Stalled drivers wait and honk before planning a bounded forward/reverse maneuver, including the opposite lane or sidewalk when space and ground support permit. Planning uses the shared task budget; control updates remain frequent. Red lights, scheduled stops and taxi passenger waits suppress recovery. Impossible maneuvers fall back to waiting and existing unseen-vehicle cleanup (`bgn_vehicle_cleanup_time`, default 120 seconds).

The `tools/dv_*.lua` fixtures use a temporary single-player file bridge on `gm_bigcity_improved`. The bridge is not shipped as an addon autorun. `python tools/dv_lab.py server <fixture.lua>` sends a fixture to the running game. Reports go to `garrysmod/data/bgn_dv_lab/`.

Fixtures cover police access (`dv_stage1`), chassis/axle alignment (`dv_headings`), NPC/NextBot detours (`dv_stage2`), blockers/turns and original-DV comparison (`dv_stage3`), scheduled-stop/no-path guards (`dv_guards`), two-way traffic (`dv_duel`), and stationary 10/30/60-car sensor benchmarks (`dv_benchmark`). Run one fixture at a time in a test session: they create entities and move the observer. Benchmark `ticks_per_second` measures server ticks, not rendering FPS. Python checks: `python tools/test_regressions.py` (requires lupa).

Local vehicle planning targets mostly level streets. Other axle layouts and steep ramps need separate calibration.

Police dismount for nearby actual enemies or critical vehicle damage; neutral observers no longer trigger dismounts or prevent returning. Previous crew may return to free passenger seats after their driver boards. `dv_return_lane.lua` exercises normal police return and physical alternate-lane recovery in an isolated lab. After two failed plans/maneuvers, idle traffic tries up to three nearby directed road segments with a different heading, respecting DV groups, road height, swept body clearance, ground support and reservations. A completed maneuver hands the driver to the new DV segment. Active destination missions and chases keep their routes. Progress during an alternate-lane maneuver means approaching its next target, not merely moving away from the jam.

Alternate-lane tracking uses the measured rear axle for four-wheel simfphys cars, brakes and replans from the physical pose at gear changes, and skips failed lane endpoints for 30 seconds. Its bounded search allows 640 nodes; normal recovery keeps 160 nodes and its original body-center tracking. Lane endpoints must be ahead along their own directed segment. Critically damaged police cars are not boarded again. The fixture records the exact native waypoint handover; polling `PrevWaypoint` alone can miss it when DV immediately advances another waypoint. `BGNReturnLaneOnly=true` runs only the lane portion.

Keep DV's native `DoTrace` interval: clear traces renew `StopByTrace` for only 0.1 seconds, so a 0.2-second scan interval causes false braking. Recovery requires speed below 25 HU/s and an obstacle or a heading error over 60 degrees; it refreshes DV traces while maneuvering and releases control when the forward route clears. Failed maneuvers restart the normal waiting period. Actor speed overrides retain DV's corner and traffic slowdown coefficients; absolute limits remain in HU/s.

`dv_damage_horn.lua` checks quiet waiting on an empty road, short honks (0.15 s, 8–14 s between requests) at a real blocker, surviving exits and fatal NPC/NextBot hits leaving ragdolls. Report: `damage_horn.json`. Honking requires a nearly stationary car and an entity hit by the forward sensor; world geometry does not trigger it. Exit floors more than 96 units above or below the car origin are rejected, keeping passengers aboard rather than placing them on another road level. Fatal seated occupants leave debris ragdolls subject to the engine's ragdoll limit.

Vehicle occupants keep the same actor object and UID in the population registry. Boarding removes the real NPC/NextBot and its weapons; the existing DV driver/passenger anim entity represents the occupant. Exiting recreates the original body kind, appearance, health and equipment at a free hull-tested position. A blocked exit retains the seat. Removing a car removes its crew, including direct entity removal. Addon-private NPC data requires a `BGN_ActorEntityChanged(actor, old, new)` integration.

`dv_lifecycle.lua` checks simultaneous boarding, NPC/NextBot removal and recreation, stable identities/counts/targets, health/equipment, blocked exits, repeat boarding and direct car removal. `dv_lifecycle_guards.lua` checks lost/failed controllers, full seats, wanted/kill history and provider cleanup. Reports: `lifecycle.json` and `lifecycle_guards.json`. Both scenarios clean up their test entities.

The admin **Carried item debugger** (`bgn_carry_debug`) issues a selected briefcase, parcel or newspaper with LMB and removes it with RMB. Aim at a living unarmed actor on foot in a calm state; model/body compatibility remains enforced. Test briefcases on male/female NPCs and NextBots through calm actions, running and combat: no physical briefcase should spawn.

Carried visual models now move with their parent entity instead of keeping a separate world render origin, so a briefcase or newspaper does not remain culled at its old location after an actor teleport.

`bgn_selftest` also runs `tests/sv_conflicts.lua`: isolated modules/hooks cover initiator direction/reset/rebind/forgetting, confirmed arrest initiation, attacker visibility, caller-visible help, foreign hostility, distinct arrest victims, strict health/distance boundaries, refusal and shared player/actor wanted thresholds. They create no live entities and do not establish engine hook timing, traces or vehicle physics.

`tests/sv_pursuit.lua` checks stable/direct-attacker/group target priorities, observation of every enemy, original shared timestamps, hidden-target approach without standoff, visible-only cover, hidden squad columns, and the inclusive combat-radius boundary. Native integration also needs ordinary non-eternal actors with the remover enabled: observe a target through an open door, close it, then add reinforcements without manually seeding their memory. Verify pursuit/siege and no recycling inside the radius, then removal after leaving it; exercise NextBot unstuck protection separately.

<a id="combat-audit-regressions"></a>

## Combat audit regressions

`bgn_selftest` loads these SERVER tests on demand, without creating live entities:

| File | Interaction checked |
|---|---|
| `tests/sv_pursuit.lua` | Real NPC adapter with modelled engine-memory refresh: search expires after more than 60 s and actual sightings renew it; real Rebind transfers hidden position/time and priorities in both realm branches; equipment follows the selected enemy with arrest fallback; both real NextBot teleport methods reject combat at 1000 and allow it at 1000.1, retaining siege protection. |
| `tests/sv_siege.lua` | Negotiation's `hold_fire` rejects both siege initiation and follower recruitment. |
| `tests/sv_negotiation.lua` | Weapon capabilities are removed and restored while door capabilities survive. |
| `tests/sv_conflicts.lua` | Friendly manhack damage is blocked in both owner/reaction hook orders, including ownership available only through inflictor; invalid owners are not substituted. |

An external LuaJIT/lupa run passed 36 tests across conflicts, lethal weapons, negotiation, pursuit, siege and GOAP planning after the fixes. The six affected checks failed against the earlier implementation. The external harness models engine APIs and is not a native `bgn_selftest` run. Native multiplayer, vehicle/door physics, real engine memory timing and script reload during these actions still require separate verification.

`tests/sv_team_damage.lua` runs 10 isolated regressions with real team, enemy, damage, wanted, arrest and vehicle-reaction modules: friendly NPC/NextBot hits with team damage off/on; help/report rejection; wanted broadcast and stale-entry cleanup; ordinary kills; SetTeam/AddTeam cleanup; repeated ramming of police on foot or in a car and a pedestrian run-over keep the driver in `residents`. `tools/test_police_force.py` also verifies a distant friendly hit is not a ranged threat. These are modelled engine calls, not native physics evidence.
