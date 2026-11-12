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
| `bgn_police_car_kill_time` | `30` | an actor in a car: seconds from the first police hit, then their next hit kills; `0` off |
| `bgn_arrest_safe_weapons` | `mlp_hoof,empty,weapon_card,...` | comma-separated weapon classes that don't count as being armed |

A player gives up by looking at the ground (pitch over 40°) near the officer. NPC targets give up by the
`arrest_surrender` state: an actor (an NPC or a NextBot body, e.g. a gangster) that attacks near the police may
give up, 5% on its first attack and 10% on each later one, only while below half its maximum health. An actor on
foot hit by an officer while it holds no active weapon and is not fighting (`defense`, `killer`, `zombie`,
`take_cover`, `pick_up_weapon`, `brawl`) gives up with 30% per hit (`systems/arrest/sv_surrender.lua`). An NPC arrest is held while the target remains compliant; the player refusal/wanted/time-limit checks below do not automatically cancel it. An attacked officer may defend itself.

A surrender never turns back into a fight: when the arrest ends or times out, the actor stops regarding the
officers as enemies. If every officer within 2500 units is busy with another target (none arrests or hunts it),
it slips away (`retreat`); otherwise it just calms down.

## Police weapon choice and witnessed harm

SERVER allows a stunstick only against a non-wanted suspect with no recorded kills, no witnessed allied victim left at or below 30% health, and at most five distinct witnessed allied victims. A sixth victim forbids the baton. Any enemy of the officer that has hit anyone (player or NPC) from farther than 500 units also forbids it, until that enemy's threat is reset. A gun in the suspect's hands alone does not forbid it. A vehicle still requires a ranged weapon. Metropolice otherwise use their assigned main weapon (pistol fallback); other police classes keep their main-weapon rules. Weapon choice is re-evaluated instead of being latched for the whole state.

`api/sv_police_force.lua` stores each officer's private `police_harm[suspect] = {victims, count, critical}`. Only actual damage counts, once per allied actor UID; the officer must witness the attacker or victim with gameplay LOS within 2500 HU, or be the victim. Wanted status does not bypass this observation. Seated actors feed the same logic after virtual health damage. Serious injury remains remembered even if that ally later heals. No global per-frame victim scan is performed.

Death (including silent player death), removal, completed arrest and normal wanted removal clear the suspect's kill evidence and all officers' corresponding harm records. Body replacement transfers records instead of counting another suspect. Bulk wanted clearing and dead-target cleanup use normal removal events. Kill counters also reset on initial wanted escalation in the existing wanted system; the separate kill flag survives that counter reset so the first kill still forbids a baton. `BGN_PlayerArrest` handlers can inspect pre-reset statistics; completed-arrest cleanup follows the hook even when an integration handles the default outcome.

During an arrest, police keep the chosen weapon. Wanted suspects, killers and serious/multiple-victim offenders stay under the main weapon; a protected surrender clears the combat enemy and holds aim without granting permission to fire. This does not change arrest eligibility or the protection against damage from law allies.

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
(the officers at the doors do not block the exit, only the world and props do; a blocked exit retries on the next tick) and gives up to the officer at the car (`ArrestModule:Surrender`): it goes
to `arrest_surrender`, the officer to `arrest`, and the usual arrest finishes it. The progress is kept on the
suspect's entity (`ent.bgn_still`); `ArrestModule:BreakinCar(ent)` returns the car of a called break-in.

A shot at a car managed by the addon (any base: a `prop_vehicle_jeep` or a scripted simfphys/LVS/Glide chassis)
hits every occupant for the full damage; a crash (`DMG_CRUSH`, `DMG_VEHICLE`) only for 1/2-1/10 of it
(`modules/dv/sv_car_damage_reaction.lua`). When the police have not killed an actor in a car within
`bgn_police_car_kill_time` seconds of their first hit on it, their next hit kills it (`Actor:TakeVehicleDamage`);
60 seconds without a police hit, or stepping out, start the time over.

## Second chance

`systems/arrest/sv_surrender.lua`: a player the police shoot at who carries only safe weapons (or nothing) and
has hurt no one for `bgn_arrest_surrender_delay` seconds is offered an arrest again, even after a rampage or
while wanted: every officer fighting the player switches to arrest (`police_surrender` voice line). Refusing
within the time limit, or any damage dealt, and they shoot again. The next chance comes after
time limit + delay. Hook: `BGN_PlayerSurrenderChance(ply, police_actor)`.

Fist fights never lead to shooting: the police arrest both fighters ([Conversations](./conversations.md)).


## Holding an arrest

An NPC arrest does not use the player wanted/time-limit checks in `CanArrest`. Officers hold the arrest unless attacked. Allied police damage to a protected active arrest target is suppressed; an attacked officer retains self-defense. Sources: `systems/arrest/sv_arrest.lua`, `brain/fsm/states/sv_arrest.lua`.
