# Arrest

Code: `lua/background_npcs_core/systems/arrest/`, the police state `brain/fsm/states/sv_arrest.lua`.
Settings window: **Arrest**.

| Cvar (server) | Default | Meaning |
|---|---|---|
| `bgn_arrest_mode` | `1` | the police try to arrest first |
| `bgn_arrest_time` | `5` | seconds the detention takes |
| `bgn_arrest_time_limit` | `20` | seconds to give up; then the police shoot |
| `bgn_arrest_surrender_delay` | `10` | the second chance (below); `0` off |
| `bgn_arrest_safe_weapons` | `mlp_hoof,empty,weapon_card,...` | comma-separated weapon classes that don't count as being armed |

A player gives up by looking at the ground (pitch over 40°) near the officer. NPC targets give up by the
`arrest_surrender` state. The police stop arresting and shoot when the target kills someone, keeps attacking,
refuses within the time limit or is wanted.

## Second chance

`systems/arrest/sv_surrender.lua`: a player the police shoot at who carries only safe weapons (or nothing) and
has hurt no one for `bgn_arrest_surrender_delay` seconds is offered an arrest again, even after a rampage or
while wanted: every officer fighting the player switches to arrest (`police_surrender` voice line). Refusing
within the time limit, or any damage dealt, and they shoot again. The next chance comes after
time limit + delay. Hook: `BGN_PlayerSurrenderChance(ply, police_actor)`.

Fist fights never lead to shooting: the police arrest both fighters ([Conversations](./conversations.md)).
