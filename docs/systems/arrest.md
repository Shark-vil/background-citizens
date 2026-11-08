# Arrest

Code: `lua/background_npcs_core/systems/arrest/`, the police state `brain/fsm/states/sv_arrest.lua`.
Settings window: **Arrest**.

| Cvar (server) | Default | Meaning |
|---|---|---|
| `bgn_arrest_mode` | `1` | the police try to arrest first |
| `bgn_arrest_time` | `5` | seconds the detention takes |
| `bgn_arrest_time_limit` | `20` | seconds to give up; then the police shoot |
| `bgn_arrest_surrender_delay` | `10` | the second chance (below); `0` off |
| `bgn_arrest_car_wait` | `6` | car break-in: seconds standing still in a car with the police at it; `0` off |
| `bgn_arrest_car_time` | `8` | car break-in: seconds it takes, then the arrest |
| `bgn_arrest_safe_weapons` | `mlp_hoof,empty,weapon_card,...` | comma-separated weapon classes that don't count as being armed |

A player gives up by looking at the ground (pitch over 40°) near the officer. NPC targets give up by the
`arrest_surrender` state: an actor (an NPC or a NextBot body, e.g. a gangster) that attacks near the police may
give up, 5% on its first attack and 10% on each later one while at 50 health or less. The police stop arresting and shoot when the target kills someone, keeps attacking,
refuses within the time limit or is wanted.

## Car break-in

`systems/arrest/sv_car_breakin.lua`: a player who stands still in a vehicle (rolling up to 64 units counts as
standing) for `bgn_arrest_car_wait` seconds while an officer after them (fighting or arresting) is on foot within
300 units of the car makes the police break in (`police_seize` line). It takes `bgn_arrest_car_time` seconds: the
player sees a bar shrinking from both sides to the middle (`cl_car_breakin.lua`, blinking in the last quarter).
Driving 64 units away cancels it; officers gone for more than 1.5 s start the wait over. At the end the player is
pulled out and arrested like at the end of an arrest (`BGN_PlayerArrest`, or the fade and `KillSilent`).

## Second chance

`systems/arrest/sv_surrender.lua`: a player the police shoot at who carries only safe weapons (or nothing) and
has hurt no one for `bgn_arrest_surrender_delay` seconds is offered an arrest again, even after a rampage or
while wanted: every officer fighting the player switches to arrest (`police_surrender` voice line). Refusing
within the time limit, or any damage dealt, and they shoot again. The next chance comes after
time limit + delay. Hook: `BGN_PlayerSurrenderChance(ply, police_actor)`.

Fist fights never lead to shooting: the police arrest both fighters ([Conversations](./conversations.md)).
