# Ghost crowd (experimental)

Garry's Mod can't afford hundreds of real NPCs. The ghost crowd fills the far distance with cheap
client-side figures (`ClientsideModel`) that look and behave like the real actors near you, in the spirit
of the "Legion" system from Serious Sam 4. Local mode only requests navigation points from the server; server mode also runs and synchronizes ghost movement.

Two modes:

- **Server** (default, `bgn_ghost_crowd 1`): the server runs the ghosts, every player sees the same ones, and a
  ghost a player walks up to becomes a real actor on its spot. The client settings then do nothing (locked in the
  menu with a note).
- **Local** (`bgn_ghost_crowd 0`): every client may invent its own ghosts. They change nothing in the game,
  players see different ones, and a ghost can't be caught: it runs away or fades.

| Cvar | Default | Meaning |
|---|---|---|
| `bgn_cl_ghost_crowd` (client) | `1` | local mode: enable the ghost crowd |
| `bgn_cl_ghost_crowd_max` (client) | `40` | local mode: the most ghosts at once |
| `bgn_ghost_crowd` (server) | `1` | server mode |
| `bgn_ghost_crowd_max` (server) | `40` | server mode: the most ghosts at once, shared fairly between the players |

Settings window: **My settings → Experimental** (client), **Spawn → Experimental** (server).

## Behaviour

- **Where:** in a ring from 0.35 to 1.5 × `bgn_spawn_radius` around the player, never inside that inner
  radius around any player (real actors live there, multiplayer included). They appear out of sight, or in
  sight farther than `bgn_spawn_radius_visibility` (the real actors' rule), with a fade-in. At the limit a ghost
  behind the player moves into view, so open areas don't look empty.
- **Looks:** model, skin and bodygroups of real actors you have seen; HL2 citizens until then.
  Models without a walk or an idle animation (vehicles, helicopters, some custom models) are skipped.
- **Mood:** taken from the real actors around you once a second. Panic when 20% or more of them are in the
  `danger` or `assault` state group, or retreating (one scared actor matters more than a dozen walkers), or
  when someone wanted is within the ghosts' ring. It lasts 10 s after the last cause; a new panic makes every
  ghost drop its goal and run. States are registered on the server only, so the actor sync sends the
  group too (`actor.state_group` on the client). Calm ghosts walk, some stand for a while (the share follows actors in `idle`).
- **Movement:** point to point (up to 700 units, a wall trace per step), feet on the ground (a trace down
  every 0.15 s, nav points often hang above it), never towards the player:
  sideways is allowed when calm, only away in panic. Ghosts don't enter the inner radius.
- **Leaving:** when the player gets inside the inner radius a ghost out of sight is removed at once, a seen one
  runs away; it fades out only when the player is very close or it has nowhere to go. Real actors spawn
  in that area instead.

## Server mode

- **Same for everyone:** a ghost walks segments `{ from, to, t0, speed }` (walk 75, run 190 units/s). The
  server sends a segment once (with the look when the ghost is new, in one message per 0.25 s for all
  changes); every client computes the position from `CurTime()` and scales the animation to that speed.
  A client that starts drawing (joined, switched it on, mode changed) asks for all ghosts at once.
- **Spawn, walk, leave:** the local rules, checked against every player: ring of each player, out of every
  player's inner radius, out of everybody's sight or farther than `bgn_spawn_radius_visibility`. Mood (panic,
  idle share) is counted per player from the server's actor states; a ghost follows its nearest player's.
  Looks (type, model, skin, bodygroups) come from real actors on foot with walk and idle animations.
- **Handoff:** a ghost someone sees, with a player inside its inner radius, becomes a real actor of the same type
  and look on its spot (dropped to the ground), facing its way. Clients keep drawing the ghost until the
  entity arrives (at most 2 s), so there is no gap and no double. An unseen ghost there just goes.
  The handoff may go over the type limit: the actor remover then takes over-limit actors that no player sees
  (never a seen one), so the count gets back within the limit without anyone vanishing in sight. On an overloaded
  server (`core/sv_server_load.lua`: fewer than 80% of the tickrate's ticks per real second, held 3 s; or more
  actors than twice the sum of the active types' limits) over-limit actors go at once, seen or not, and handoffs
  stay within the limit. When the type
  is off (or its limit is 0) or the spawn fails, the ghost runs away and fades like a local one.
- Not in server mode: the "ghost behind the player moves into view" at the limit.

- `systems/sh_ghost_crowd.lua`: rules of both modes (next point, sight, segments, radii).
- `systems/cl_ghost_crowd.lua`: ghosts, mood, movement (client); draws the server's ghosts in server mode.
- `systems/sv_ghost_crowd.lua`: answers `bgn_ghost_crowd_points` with the nav points around the player
  (once per 2 s per player, up to 1500 points). Answers are cached for 15 s per 1024-unit map cell and radius,
  so players near each other share one navigation query. Server mode: runs the ghosts (`bgn_ghost_crowd` /
  `bgn_ghost_crowd_sync` messages).

`bgNPC.Nav.GetPointsInRadius(center, radius, link_type, limit)` takes an optional `limit`; the navmesh
provider returns 64 points by default.

Self-test: `bgn_selftest` / `bgn_selftest_cl` → `ghost_crowd_rules`.

## Known limits

- Every ghost animates every frame; 100+ ghosts may cost noticeable FPS.
- On a navmesh the points come from about ±256 units of height around the player, hilly maps get fewer ghosts.
- The fade-out uses `render.SetBlend` in the opaque pass, which can show artifacts while fading.
