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
`take_cover`, `pick_up_weapon`, `brawl`) gives up with 30% per hit (`systems/arrest/sv_surrender.lua`). Players and actors share the refusal time limit and the escalation rules below. An attacked officer may defend itself.

A surrender never turns back into a fight: when the arrest ends or times out, the actor stops regarding the
officers as enemies. If every officer within 2500 units is busy with another target (none arrests or hunts it),
it slips away (`retreat`); otherwise it just calms down.

## Police weapon choice and witnessed harm

SERVER allows a stunstick only against a non-wanted suspect with no recorded kills, no witnessed allied victim left at or below 30% health, and at most five distinct witnessed allied victims. A sixth victim forbids the baton. Any enemy of the officer that has hit anyone (player or NPC) from farther than 500 units also forbids it, until that enemy's threat is reset. A gun in the suspect's hands alone does not forbid it. A vehicle still requires a ranged weapon. Metropolice otherwise use their assigned main weapon (pistol fallback); other police classes keep their main-weapon rules. Weapon choice is re-evaluated instead of being latched for the whole state.

`api/sv_police_force.lua` stores each officer's private `police_harm[suspect] = {victims, count, critical}`. Only actual damage counts, once per allied actor UID; the officer must see the attacker with gameplay LOS within 2500 HU (also FOV for an attacking actor), or be the victim. Wanted status does not bypass this observation. Seated actors feed the same logic after virtual health damage. Serious injury remains remembered even if that ally later heals. No global per-frame victim scan is performed.

Death (including silent player death), removal, completed arrest and normal wanted removal clear the suspect's kill evidence and all officers' corresponding harm records. Body replacement transfers records instead of counting another suspect. Bulk wanted clearing and dead-target cleanup use normal removal events. Kill counters also reset on initial wanted escalation in the existing wanted system; the separate kill flag survives that counter reset so the first kill still forbids a baton. `BGN_PlayerArrest` handlers can inspect pre-reset statistics; completed-arrest cleanup follows the hook even when an integration handles the default outcome.

During an arrest, police keep the chosen weapon. Wanted suspects, killers and serious/multiple-victim offenders stay under the main weapon; a protected surrender clears the combat enemy and holds aim without granting permission to fire. This does not change arrest eligibility or the protection against damage from law allies.

Refusal or an escalation condition below ends the arrest and makes a player or actor wanted if
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
within the time limit, or meeting the harm/escape conditions below, ends the chance. The next chance comes after
time limit + delay. Hook: `BGN_PlayerSurrenderChance(ply, police_actor)`.

Fist fights never lead to shooting: the police arrest both fighters ([Conversations](./conversations.md)).


## Holding an arrest

Players and actors use the same refusal deadline. One primary officer conducts the arrest; other officers in the arrest state remain ready without advancing detention. Officers hold the arrest unless attacked. Allied police damage to a protected active arrest target is suppressed; an attacked officer retains self-defense. Sources: `systems/arrest/sv_arrest.lua`, `brain/fsm/states/sv_arrest.lua`.

## Escalation during an arrest

SERVER starts an arrest after confirmed damage, so blocked/zero hits do not start one and the opening hit is not a subsequent violation. During that attempt, any of these ends arrest and requests wanted status:

- Refusal after `bgn_arrest_time_limit` while not in detention (players and actors).
- Damage to a police actor, or killing a player, NPC or actor.
- Damage leaving a non-police actor below 30% of maximum health, unless that victim initiated its conflict with the suspect.
- Damage to more than three distinct non-police actors that did not initiate their conflicts with the suspect. Repeated hits count once per actor UID, for this arrest attempt.
- Leaving the primary officer's 250-unit zone after that officer first reached it. Until then, moving while the officer approaches is not escape. The last close officer position and suspect movement are checked too, so an officer moving away cannot alone trigger escape.

Compliance is checked every 0.25 seconds and during primary-officer updates, independently of AI state/LOD. Actual detention still needs a distance of 200 units and the surrender pose. Damage limits use confirmed post-damage health, including seated actors. Body replacement preserves the arrest attempt and its victim count. Exactly 30% and exactly three victims do not escalate. These limits are separate from the weapon-choice thresholds above. With wanted disabled, escalation still ends arrest; peaceful mode prevents wanted assignment. See [conflict memory](wanted.md#conflict-memory-and-witnesses).

Damage to the primary officer's known enemy is excluded from the non-police victim count and the below-30% injury condition when the suspect and officer have no existing enemy relationship or `D_HT` in either direction. The same rule prevents initiating an arrest solely for attacking a common enemy. Hitting a police actor, killing during arrest, refusal and escape keep their separate escalation rules. The weapon-choice harm memory also excludes such common-enemy hits; range and kill evidence retain their existing meaning. See [conflict rules](wanted.md#conflict-memory-and-witnesses).

<a id="arrest-decision-tree"></a>

## Arrest decision tree

This SERVER branch follows the [damage and enemy-selection tree](wanted.md#behavior-decision-tree). It describes the local 2.5.1 working tree, not verified Workshop behavior.

```text
Confirmed damage by a player/ACTOR
├─ Arrest mode off or the attacker already wanted → do not start a new arrest here
├─ No existing arrest record
│  ├─ Find an officer: the victim if police, otherwise within 700 of A, then V
│  ├─ Officer is not the victim → must witness the real attacker
│  ├─ ResolveEnemy returns none (including common enemy) → no arrest
│  ├─ Chosen side is foreign, neither player nor ACTOR → request enemy, no arrest
│  └─ Chosen side is player/ACTOR → create arrest record and assign primary officer
│     └─ An ACTOR must surrender to enter detention; otherwise the record can
│        persist while the officer defends, with compliance checked by the timer
└─ Existing arrest: harm was evaluated before BGN_ConfirmedDamage
   ├─ Damaged victim is a police ACTOR → escalate
   ├─ Victim is not an ACTOR → no injury/victim-count escalation
   ├─ Common-enemy exception for the primary officer → exclude this hit
   ├─ Victim initiated its conflict with the suspect → exclude this hit
   └─ Other non-police ACTOR → count each UID once
      └─ Count >3 or post-damage health <30% → escalate

Death callbacks: the suspect kills someone during an active arrest → escalate
(independent of the injury exemptions above)

Primary-officer compliance (timer every 0.25 s, plus state updates)
├─ Mode off / no active record → no escalation here
├─ No living primary officer found → wait for replacement; no compliance check
├─ Officer within 250 → refresh the last close officer position
├─ Officer has never been within 250 → no escape yet; deadline check still applies
├─ Both current and last-close officer distances >250, and suspect moved
│  └─ Escape → escalate
└─ Not detained and warning deadline expired → refusal → escalate

Escalate
├─ Mark this attempt non-arrestable and return the primary officer to defense
└─ Wanted enabled and not peaceful → request wanted (normal exclusions remain)
```

The warning deadline starts when the record is created; waiting for the officer to approach does not pause it. Escape and actual detention have different radii (250 and 200). Health/count exemptions do not excuse a police hit or an arrest-time kill. Weapon choice is a separate assessment, not another route to automatically assign an enemy. Successful detention, body replacement and second-chance behavior follow the sections above.
