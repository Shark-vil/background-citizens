# Actor brains

An actor is split into an **actor** (data and rules), a **body** (`actor.body`: everything that talks to the
engine entity: movement, schedules, relationships, weapons, animation) and a **brain** (`actor.brain`: decisions).
Bodies and brains exist on the server only.

## Bodies

`bgn_actor_body npc|nextbot` (default `npc`; the old value `auto` is the same as `npc`). By default actors are real HL2 NPCs (`NPCBody`), like in the old versions: other addons (model replacers, ragdoll and death mods, Bio-Annihilation 2, Followers) see only real NPCs (`IsNPC`, `OnNPCKilled`). With `nextbot`, on maps with a NavMesh, actors of the HL2 classes
`npc_citizen`, `npc_metropolice` and `npc_combine_s` spawn as `bgn_nextbot` (NextBot, `NextBotBody`), and such addons may not work with them. The NextBot walks with the NavMesh path follower, opens doors (the ones allowed, see navigation.md "Doors"), gets unstuck, and
shoots or hits with a real HL2 weapon held in its hand (players can't pick it up while the bot is alive; it drops
the weapon on death, like an HL2 NPC). Shots start at the bot's right hand. The config `weapon_skill` works for
NextBots too: the spread scales like the HL2 NPC cone (poor ×1.4, average ×1, good ×0.67, very good ×0.33,
perfect ×0.2). HL2 NPCs that the bot hates are told to hate it back.

## Weapons and teams

- Only actors whose weapon roll passed (`getting_weapon_chance`, 10% of citizens) are armed.
- An unarmed actor in `fear` / `run_from_danger` runs to a free weapon within 500 units (`pick_up_weapon`) and
  fights with it. It was spawned without a weapon, so it always shoots with `WEAPON_PROFICIENCY_POOR`
  (`actor.novice_shooter`, `bgNPC.Combat.ApplyWeaponSkill`). The same goes for an HL2 NPC that picked a weapon
  up by its engine AI.
- Actors of one team never damage or answer each other. `bgn_team_damage 1` lets the damage through,
  they still don't react to it.
- A wanted actor (`Actor:IsWanted`, wanted is lost by NPCs exactly like by players) hides: a `defense` reaction
  turns into `retreat`, which fights back only when the enemy is within 190 units; `defense` returns to `retreat`
  when the enemy is over 300 units away.

## Choosing a brain

`bgn_brain auto|fsm|goap` (default `fsm`, the classic brain). In `auto` an actor gets the brain from its config field
`brain = 'fsm' | 'goap'`, otherwise GOAP when the config has `weapons`, otherwise FSM.

## FSM brain

Runs the `update` callback of the current state (`bgNPC.States`), and picks a random state from `at_random`
when the actor has none. Reactions to damage and threats are random picks from `at_damage` / `at_protect`.

## GOAP brain

Used while the actor has enemies; without enemies it behaves like the FSM brain.

- **Facts** are measured by sensors once per second (and right after damage or a new enemy):
  `has_enemy`, `armed`, `is_police`, `low_health`, `enemy_close`, `enemy_armed`, `enemy_police`, `police_called`,
  `wanted`, `in_cover`, `backup_called`, `surrendered`.
- **Actions** run states: `attack` → `defense`, `flee` → `fear`, `call_police` → `calling_police`,
  `hide` → `retreat` (wanted actors only), `take_cover` → `take_cover`, `call_backup` → `call_backup`,
  `surrender` → `arrest_surrender`.
  An actor can only use actions whose state appears in its `at_damage` / `at_protect` config with a weight
  above zero, except actions registered with `always = true` (`hide`, `take_cover`, `call_backup`).
  A trait action is rolled once per actor: `call_police` with its config share (20 of 100 → 20%), `surrender`
  with its `chance` (50%).
  An action stays running while its state moves on to a follow-up (`also`, e.g. `fear` → `run_from_danger`).
  An action that fails (its state ends or redirects on its own) is blocked for 5 s, then the plan is made again.
- **Chains.** Fighting an armed enemy costs more out of cover, and for the police without backup, so the plans are
  `take_cover → attack` and, for the police, `call_backup → take_cover → attack`:
  - `take_cover`: runs to the nearest nav point within 1000 units the enemy can't see at crouch height
    (`bgNPC.FindCover`), crouches 3 s, then fights 10 s (`in_cover`) before the next cover. No cover found: it
    fights.
  - `call_backup`: the officer calls on the radio (`police_backup`); up to 3 free officers on foot within 4000
    units take the enemy and come. Once per officer per minute.
  - `surrender`: a hurt gangster (`low_health`) facing the police gives up (goal `give_up`, above hiding) when an
    officer within 700 units sees it and `bgn_arrest_mode` is on: it says `give_up`, the officer arrests it
    (`systems/arrest`). The plan never interrupts `arrest_surrender`.
- Arrests are not planned: the arrest system (`systems/arrest`, `ArrestModule:CanArrest`) owns them, and it
  only works on police without enemies.
- **Goals** (`eliminate`, `survive`, `report`, `hide`) get a priority from the actor's **set**: `police`,
  `gangster` or `citizen` (by team, or the config field `goap_set`). `hide` outranks the rest while wanted.
  A citizen reports (calls the police) an enemy farther than 700 units even when it is armed, unless it is hurt
  (then it runs) or armed itself (then it fights).
- The planner (A* over fact bit masks) returns the cheapest action chain for the top goal. Plans are cached.
- `ignore` in a reaction table keeps its random chance.

Debug: `bgn_goap_debug` prints the set, goal, plan and facts of the actor you look at.

### Extending

```lua
bgNPC.GOAP.RegisterAction('duck', {
	state = 'retreat',                      -- a registered state that performs the action
	pre = { has_enemy = true, enemy_armed = true },
	effects = { safe = true },
	cost = function(ws) return 1 end,       -- number or function(world_state)
	-- optional: always = true (no config weight needed), trait = true + chance = 0.3 (rolled once per actor),
	-- prepare = function(actor) return true end (sets up before the state starts; false blocks the action)
})
bgNPC.GOAP.sensors.my_fact = function(actor, npc, enemy) return ... end
bgNPC.GOAP.RegisterSet('my_set', { survive = function(ws) return 10 end })
```

## Squads

`bgn_module_tactical_groups` (on by default). Every second actors in `defense` of one team within 1200 units
form squads of up to 5. The healthiest leads, its nearest enemy becomes the target of every member.
Formations face the target: `column` when nobody sees it, `wedge` with 4+ healthy members, `line` otherwise.
The healthiest stand in front, the wounded (< 40% health) form a rear rank. `defense` moves a member to
`actor.squad.slot`; `bgNPC.Squads.list` holds the current squads.

## LOD

Actors far from players update less often (`bgn_lod_near_radius`); idle unarmed actors out of range sleep
(`bgn_disable_logic_radius`). Hook: `BGN_ActorLODChanged(actor, lod)` (1 near, 2 far, 3 dormant).

## Medics

Actor type `medic` (`config/actors/sh_medic.lua`, limit 4: two pairs) is never spawned by the regular spawner. Every actor
death outside a vehicle is a call (`bgNPC.Medics.calls`, kept 90 s). A free medic takes it, otherwise one is
spawned near the body, with an ambulance when Decent Vehicle is on and the config has `vehicles`. The ambulance
drives to the body like a police car on a chase, the medic gets out, kneels over the body for 6 s with voice
lines and medkit sounds (state `medic_revive`), the actor comes back (same type, model and skin; its ragdoll is
removed) and the medic returns to the car. A call closes when the body is gone (a client reports its ragdoll
faded or was cleaned up, or the server ragdoll was removed) or after 90 s; the medic then walks back to its car
and drives on with the siren off. The last 300 units to the body the medic walks straight, off the nav points.
Medics only take as enemies those who hurt them. Nobody comes for an actor killed by the police (team `police`).

When a medic is killed, medic spawns and responses are blocked around the death position. Existing calls
in that area pause: their responders stop heading to the body and return to their ambulance when possible.
`bgn_medic_danger_time` defaults to 60 seconds (`0` disables the restriction), and
`bgn_medic_danger_radius` defaults to 1500 units; both are in the behavior settings under Medics.
The area reopens when the timer expires **or** the killer dies (player, NPC or NextBot actor).
Areas belonging to other killers remain blocked. Pending calls can resume while their original 90-second
lifetime remains; the restriction does not extend that lifetime.
Hook: `BGN_ActorRevived(actor, call)`.

- **Pairs:** a medic spawned for a call brings a partner when the limit allows (`medic_partner` on both). It rides
  in the same ambulance (seats: 2), gets out with the medic, kneels beside the body (`call.partner`) and gets
  back in with it; a partner within 400 units of the car is pulled in when the medic takes the wheel.
- **Ambulances:** no new one when a player near the call (3000 units) already has an ambulance around; an empty
  ambulance there is taken instead.
- **Attacked:** by a player, the medic reviving keeps reviving (a life first) and its partner fights with fists
  (state `brawl`); a medic not reviving fights itself. Below 30 % health a medic leaves the call (the partner
  takes it over) and runs, by its car when one is near (`go_to_police_car`, then `fear`). Attacked by an actor,
  it runs as before.

## Police at a body

Every actor death outside a vehicle also leaves a body for 60 s (`brain/fsm/states/sv_police_inspect_body.lua`).
The nearest officer within 2000 units who walks or idles without enemies takes it (state `police_inspect_body`):
walks to the body, crouches over it, reports it on the radio (`police_body_report`) and writes it down
(`police_body_notes`), 5 s each, then goes on patrolling. Bodies from a shoot-out are taken once the officers
calm down; a body revived by a medic is dropped.

## Onlookers

Every actor death outside a vehicle is also an incident for 45 s (`brain/fsm/states/sv_watch_incident.lua`).
From 5 s after it, calm civilians walking or idling within 1500 units come one by one (35% per 2 s check, up to 4):
they stand 150-280 units from the spot on their side, stare (`LineIdle*`), half of them say a `watch_incident` line,
and go on after 12-25 s. A gunshot scares them like any calm actor; two of them may start a conversation.

## Bodies

`systems/sv_corpses.lua`, `systems/cl_corpses.lua`. Settings window: **Behavior > Bodies**.

| Cvar (server) | Default | Meaning |
|---|---|---|
| `bgn_corpse_cleanup` | `0` | the bodies of dead actors (NPC and NextBot) fade out (off by default) |
| `bgn_corpse_cleanup_time` | `60` | seconds after the death |

A body a medic is assigned to, or an officer is inspecting, waits until they are done (both end on their own:
the call after 90 s, the inspection after its give-up time). Server ragdolls fade on the server, client ragdolls
on every client. [npc_battle_cleanup](https://steamcommunity.com/sharedfiles/filedetails/?id=2120936972) would
remove a body in seconds, before a medic or an officer gets to it, so the actors' bodies are left to this
setting: server ragdolls get its `doNotRemove` flag, its client-side corpse cleanup skips them.
With `bgn_corpse_cleanup 0` (the default) the flag is not set and npc_battle_cleanup, if installed, removes the bodies as usual; without it they stay until the engine's own ragdoll limits remove them.

## Cars

Police dismount when a living player is within 800 units or their vehicle has at most 20% health remaining.
Simfphys health uses `GetCurHealth()` and `GetMaxHealth()`; vehicles without a positive maximum health do
not trigger the damage condition. A hit alone no longer makes police dismount. Vehicle removal, forced
ejection and releasing passengers left without a driver still detach them from the vehicle.

Actors and Decent Vehicle cars; the state `go_to_police_car` (no longer police only) runs to the car and gets in.

- **Back to the car** (`modules/dv/sv_return_to_vehicle.lua`, every 2 s): an actor within 1000 units of an empty
  car, walking or in a fight with every player and enemy at least 1500 units away, gets back in.
- **The enemy drives off** (`sv_defense.lua`, every 2 s, 30 %): a player in a vehicle or an actor in a car; checked
  before the squad move, so squad members go too.
- **Confiscation and carjacking** (`data.seize`): when no car of its own is near, the police take a car of another
  group ("police_seize") and bandits carjack one ("gangster_carjack"): whoever sits inside is thrown out
  (`VEHICLE:Eject`, scared unless it is a teammate) and the car joins the actor's group (`VEHICLE:SetGroup`: the
  police get the chase AI). Bandits on the run (`retreat`, `fear`, `run_from_danger`) within 700 units of such a
  car take it too (35 % per check) and keep running in it.

NextBots and cars (`systems/sv_nextbot_vehicle_hits.lua`): a NextBot has no physics object, so the engine deals it
no crush damage. Every 0.1 s each moving car (players', Decent Vehicle ones) faster than 150 u/s hurts NextBots in
its box and just ahead ((speed - 75) x 0.25, the driver is the attacker) and throws them. A NextBot whose enemy
sits in a car shoots the car (the enemy is the car then, which has no health of its own).

Which car: `VEHICLE:CanBoard`: an empty one the actor left, or of its group (`police`, `bandits`, `medics`, ...),
never someone else's `residents` car (police and medics are residents too, citizens keep to their own).
`VEHICLE:CanSeize`: a car of another group, empty or driven by an actor (never a player), not driven by a
teammate. Only the police and bandits seize.
