# Ghost crowd (experimental)

Garry's Mod can't afford hundreds of real NPCs. The ghost crowd fills the far distance with cheap
client-side figures (`ClientsideModel`) that look and behave like the real actors near you, in the spirit
of the "Legion" system from Serious Sam 4. The server pays nothing: it only sends navigation points.

On by default. Settings window: **My settings → Experimental**.

| Cvar (client) | Default | Meaning |
|---|---|---|
| `bgn_cl_ghost_crowd` | `1` | enable the ghost crowd |
| `bgn_cl_ghost_crowd_max` | `40` | the most ghosts at once |

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

## Files

- `systems/cl_ghost_crowd.lua`: ghosts, mood, movement (client).
- `systems/sv_ghost_crowd.lua`: answers `bgn_ghost_crowd_points` with the nav points around the player
  (once per 2 s per player, up to 1500 points). Answers are cached for 15 s per 1024-unit map cell and radius,
  so players near each other share one navigation query.

`bgNPC.Nav.GetPointsInRadius(center, radius, link_type, limit)` takes an optional `limit`; the navmesh
provider returns 64 points by default.

Self-test: `bgn_selftest_cl` → `ghost_crowd_next_point`.

## Known limits

- Every ghost animates every frame; 100+ ghosts may cost noticeable FPS.
- On a navmesh the points come from about ±256 units of height around the player, hilly maps get fewer ghosts.
- The fade-out uses `render.SetBlend` in the opaque pass, which can show artifacts while fading.
