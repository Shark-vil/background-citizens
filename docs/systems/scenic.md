# Scenic scenes

Staged scenes that appear on the map by themselves: a food line, a cop knocking on a door, a couple on a couch,
someone sitting on a chair, an arrest at a wall. 26 scene definitions, 21 enabled for automatic spawning;
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
`couch_couple`, `couch_lying`, `radio_operator`, `sky_watch` and `door_brace` have `weight = 0`: they remain
available for manual spawning but are never selected automatically, avoiding furniture and context-dependent
poses appearing at arbitrary locations.

## How a scene is placed

1. The `bgn_scenic` task (`systems/scenic/sv_scenic_spawner.lua`) picks a scene by weight, with a back-off
   cooldown per scene that failed to find a place (20 s doubling up to 600 s).
2. `sv_scenic_finders.lua` takes seeds by the `place` of the scene: navigation points of the spawn ring
   (`floor`, `sky`, `wall`) or doors and chairs from an entity index cached for 30 s (`door`, `chair`).
3. A finder checks the seed: flat floor, room for a hull, open sky above (`sky`), a flat wall (`wall`), a closed
   door with a clear side (`door`, opening/closing doors are rejected), a free chair (`chair`).
4. `Plan` checks the floor, the level and the room of every member. Scenes keep 400 units from each other and out
   of sight of players (`IsHiddenSpawnPosition`).

## Actors

Members play a looped sequence in the `scenic_npc` state (calm group). Calm states do not pull them out; a
reaction to danger (shot, hit, wanted) does, then they are normal actors again. Conversations skip them.
Door scenes (`door_knock`, `door_brace`, `entrance_block`) also end for each participant when the linked door
starts opening or is removed. The server stops the animation and returns the actor to normal AI; the actor
is kept alive and is no longer removed with the scene. `door_knock` aligns its sideways-authored animation
with the door so the raised hand reaches the panel.
A scene that nobody sees is removed after `ttl` seconds (default 600).

Offline door placement/lifecycle checks: `python tools/test_scenic.py` (requires lupa).

## Adding a scene

Add an entry to `bgNPC.cfg.scenic`; the fields are described at the top of `sh_scenic.lua`. A model that lacks
a sequence plays the next one of the list; a scene whose sequences no model has is skipped.
Models, skins and bodygroups come from ordinary actor spawning, including actor config and model hooks.
Scenes do not override models (`members.models` is ignored); participants without a supported sequence are
skipped instead of being given a different model. Set `weight = 0` to keep a scene manual-only.

Not ported: scenes with custom sounds, rappel, APC, binoculars and characters of the original addon.
