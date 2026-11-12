# Scenic scenes

Staged scenes that appear on the map by themselves: a food line, a cop knocking on a door, a couple on a couch,
someone sitting on a chair, an arrest at a wall. 28 scene definitions, 23 enabled for automatic spawning;
all data is in `config/states/sh_scenic.lua`.
The actors are ordinary actors (`bgNPC:SpawnActor`), so they work with an NPC body and with a NextBot body.

| Cvar (server) | Default | Meaning |
|---|---|---|
| `bgn_scenic` | `1` | scenes on / off |
| `bgn_scenic_max` | `4` | scenes at once |
| `bgn_scenic_period` | `30` | seconds between spawn attempts |

Menu: **Spawn** page, section "Scenic scenes", and the *Scenic scenes* step of the wizard (New mode on, Classic off).
Console: `bgn_scenic_clear` removes every scene, `bgn_scenic_spawn <id>` (admin) makes one near you.
For door scenes, aim at a fully closed door; the command uses the same placement finder as automatic spawning.
Knocking does not require a lock: both unlocked and locked doors work. The scene never locks the door;
as soon as it starts opening, the actor leaves the pose and resumes normal behavior.
Manual placement by an administrator allows spawning in sight and nearby, while keeping floor, room, scene
placement and actor-model checks. Automatic spawning still requires hidden positions.
Each automatic scene has its own checkbox on the Spawn page (also in Classic settings), backed by
`bgn_scenic_<id>`; it affects future automatic selection, not existing scenes or manual Tool placement.
`sky_watch`, `door_brace`, `luggage`, `ration` and `newspaper` have `weight = 0` and stay manual-only. Carry previews create one walking carrier (ration/newspaper require NextBots, luggage uses a client-only briefcase on HL2 NPCs); ordinary citizens get these items through their [actor config](../tutorials/Modification-of-Existing-NPCs.md).

## Scene debugger Tool

Open **Q → Tools → Background NPCs → Scene debugger** (administrators only). The panel lists all 28 scene
IDs, including five manual-only previews, plus a **GOAP: hold, breach, recover** test.

| Control | Action |
|---|---|
| Left click | Create the selected scene at the aimed floor/wall, fully closed door or supported free chair. |
| Right click on an actor or temporary ragdoll | Inspect the actor's UID, actual body class, state, health, model, sequence and linked door. GOAP details also print to your console. |
| Right click on empty space | Return to the last scene's summary and model/sequence failure messages. |
| R | Remove the last test created with this Tool, including actors that have already resumed normal behavior. |
| Undo / Z | Undo a Tool or `bgn_scenic_spawn` placement. Existing map doors/chairs are retained. |

For walls, aim near the floor so the finder can find the ground; sky scenes need open sky. A rejected placement
shows its reason. If a normally selected actor model lacks the animation, the HUD reports its model and requested
sequences; the model is never replaced. Removing a chair test frees the chair for immediate retesting.
For a door scene, aim directly at the door panel. Wrong targets, open/moving doors, and insufficient floor
space have separate error messages; pointing at the floor beside a door does not select it.

The door test starts at a **closed, unlocked rotating door** with free space on both sides. It spawns a citizen
and an officer using normal model selection and the current server body setting, gives only this pair GOAP,
sets the holder to 25% health so it seeks shelter, then opens the door. The citizen closes/holds it, the officer
kicks it open, and the citizen falls and recovers. The officer stops fighting after one kick. Follow the live
phase/state HUD; use R or Undo to remove the pair afterwards. A model without `doorbracer_*` or an unreachable
position is reported rather than forcing a different model or bypassing AI movement.

To compare bodies, change `bgn_actor_body npc` / `bgn_actor_body nextbot` in the normal server settings and
create a new test; NextBots require a NavMesh. The Tool does not change global body/brain settings. AI around
the test remains active, so use a quiet test area. Placement and diagnostics are server-authoritative;
the client only selects a scene and displays the report. Tests are owned by their creator and removed on disconnect.
Actors from this Tool or `bgn_scenic_spawn` are excluded from automatic removal/recycling and scenic
distance/visibility/lifetime cleanup, even after leaving their pose. R, Undo, explicit cleanup and death still work.

## How a scene is placed

1. The `bgn_scenic` task (`systems/scenic/sv_scenic_spawner.lua`) picks a scene by weight, with a back-off
   cooldown per scene that failed to find a place (20 s doubling up to 600 s).
2. `sv_scenic_finders.lua` takes seeds by the `place` of the scene: navigation points of the spawn ring
   (`floor`, `sky`, `wall`, `ledge`) or doors and chairs from an entity index cached for 30 s (`door`, `chair`).
3. A finder checks the seed: flat floor, room for a hull, open sky above (`sky`), a flat wall (`wall`), a closed
   door with a clear side (`door`, opening/closing doors are rejected), a free chair (`chair`), or a wide ledge with a knee-height drop (`ledge`).
4. `Plan` checks the floor, the level and the room of every member. Scenes keep 400 units from each other and out
   of sight of players (`IsHiddenSpawnPosition`).

## Actors

Members play a looped sequence in the `scenic_npc` state (calm group). Calm states do not pull them out; a
reaction to danger (shot, hit, wanted) does, then they are normal actors again. Conversations skip them.
Door scenes (`door_knock`, `door_brace`, `entrance_block`) also end for each participant when the linked door
starts opening or is removed. The server stops the animation and returns the actor to normal AI; the actor
is kept alive and is no longer removed with the scene. `door_knock` aligns its sideways-authored animation
with the door so the raised hand reaches the panel.
An automatic scene is removed after `ttl` seconds (default 60) once nobody watches it, even inside the spawn radius: no player
is within `bgn_spawn_block_radius`, and none looks toward it with a clear line to the scene (a world trace). The check runs every 5 s.

Offline door placement/lifecycle checks: `python tools/test_scenic.py` (requires lupa).

## Adding a scene

Add an entry to `bgNPC.cfg.scenic`; the fields are described at the top of `sh_scenic.lua`. A model that lacks
a sequence plays the next one of the list; a scene whose sequences no model has is skipped.
Models, skins and bodygroups come from ordinary actor spawning, including actor config and model hooks.
Scenes do not override models (`members.models` is ignored); participants without a supported sequence are
skipped instead of being given a different model. An `atomic = true` scene (the couch pair) is cancelled
as a whole if either participant lacks a usable pose. Set `weight = 0` to keep a scene manual-only.

Not ported: scenes with custom sounds, rappel, APC, binoculars and characters of the original addon.

## Placement and pose rules

Both couches and the radio desk are automatic again, with `indoors = true`. Placement requires a solid
ceiling within 384 units and walls in all four horizontal directions within 512 units, plus a dry flat floor.
Sky ceilings, open courtyards and furniture whose rotated bounds intersect brush geometry are rejected.
This conservative check can reject a real room with an open doorway/window; it also applies to the Tool.

`ground_sit` creates one citizen with a supported pose selected from a list. Plain standing scenes (`plaza`, `tired`) were
removed: their poses (`plazastand*`, `idle_subtle`, `d2_coast03_postbattle_idle02`) now belong to the `idle` state. The raised-arm tired pose is `tired_wall`, facing its support.
`ledge_sitting` needs a flat lip at least 32 units wide, 28 units of support behind it, clear standing room,
and a 24–56 unit drop in front. Short downward traces also require support directly below the pelvis
and 10 units to either side; the actor faces the lower surface. Thin rails, ordinary stair steps and deep falls are rejected.
Seated NextBots temporarily stop locomotion and disable the solid mask and gravity, preventing physics from
lifting them above a chair, custom bench seat or ledge. Stopping the body clears both desired speed and velocity; leaving the scene restores the original mask and gravity.

Member `pos.z` and per-sequence `seq_offsets` are retained; spawning uses a separate safe standing position.
Leaving the pose restores that standing position, so below-origin seated animations do not strand the actor
in the floor or ledge. Couch seating uses one calibrated furniture model; normal actor model selection is retained.
