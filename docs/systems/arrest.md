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
give up, 5% on its first attack and 10% on each later one, only while below half its maximum health. An NPC arrest is held while the target remains compliant; the player refusal/wanted/time-limit checks below do not automatically cancel it. An attacked officer may defend itself.

A surrender never turns back into a fight: when the arrest ends or times out, the actor stops regarding the
officers as enemies. If every officer within 2500 units is busy with another target (none arrests or hunts it),
it slips away (`retreat`); otherwise it just calms down.

Regular police (`npc_metropolice`) use the stunstick as an additional melee weapon. An already hostile
target holding an unsafe ranged weapon makes the officer select a pistol immediately, even up close
and before the first kill or hit. Against other targets, switching to the pistol requires at least one
kill, an attack within the last 10 seconds and a distance greater than 75 units. Once selected, the pistol
stays selected in the current combat state: closing in, the target switching weapons or a pause in attacks
does not bring back the baton. An already drawn pistol is also kept. Missed bullet shots count as attacks.
An active arrest stops combat. Other law enforcement keeps its existing shooting and arrest rules.

When a player refuses arrest and the officer abandons the arrest attempt, the player becomes wanted if
`bgn_enable_wanted_mode` is enabled. An existing wanted record is neither reset nor extended. Disabling
arrest mode does not count as a refusal.

## Car break-in

`systems/arrest/sv_car_breakin.lua`: a suspect (a player, or an actor that is not an officer) who stands still in a vehicle (rolling up to 64 units counts as
standing) for `bgn_arrest_car_wait` seconds while the police are after them (fighting or arresting, within 2000
units). The officers then hold fire, get out of their cars and run to it (state `police_car_breakin`: their enemies
are put aside and come back when it stops). Once one is within 300 units the break-in starts (`police_seize` line)
and takes `bgn_arrest_car_time` seconds: a player sees a bar shrinking from both sides to the middle
(`cl_car_breakin.lua`, blinking in the last quarter). Driving 64 units away cancels it and the officers fight
again. The officers can't be pulled away by anything else (`not_stop`; only forced states such as an arrest);
an officer stepping away from the car only pauses the bar, it never starts over. At the end the player is pulled out and arrested
like at the end of an arrest (`BGN_PlayerArrest`, or the fade and `KillSilent`). An actor is pulled out of the car
(a blocked exit retries on the next tick) and gives up to the officer at the car (`ArrestModule:Surrender`): it goes
to `arrest_surrender`, the officer to `arrest`, and the usual arrest finishes it. The progress is kept on the
suspect's entity (`ent.bgn_still`); `ArrestModule:BreakinCar(ent)` returns the car of a called break-in.

## Second chance

`systems/arrest/sv_surrender.lua`: a player the police shoot at who carries only safe weapons (or nothing) and
has hurt no one for `bgn_arrest_surrender_delay` seconds is offered an arrest again, even after a rampage or
while wanted: every officer fighting the player switches to arrest (`police_surrender` voice line). Refusing
within the time limit, or any damage dealt, and they shoot again. The next chance comes after
time limit + delay. Hook: `BGN_PlayerSurrenderChance(ply, police_actor)`.

Fist fights never lead to shooting: the police arrest both fighters ([Conversations](./conversations.md)).


## Holding an arrest

An NPC arrest does not use the player wanted/time-limit checks in `CanArrest`. Officers hold the arrest unless attacked. Allied police damage to a protected active arrest target is suppressed; an attacked officer retains self-defense. Sources: `systems/arrest/sv_arrest.lua`, `brain/fsm/states/sv_arrest.lua`.
