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


In `nextbot` mode regular HL2 NPCs have no relationship with the bodies (the engine only knows NPC classes), so `systems/sv_nextbot_hostility.lua` once per second gives every NPC within 2500 units the relationship it has with the actor's original class, measured on a hidden probe NPC of that class: an Enemy Rebel attacks nextbot actors as it did real NPCs. Skipped in peaceful mode and with `bgn_ignore_another_npc`.

Without a weapon some models (Combine soldiers) have no plain idle/walk/run and would T-pose, so the bot falls
back to the armed ones (`ACT_IDLE_SMG1`, `ACT_WALK_RIFLE`, `ACT_RUN_RIFLE`, then the pistol ones). Jumps are off by
default (`bgn_nextbot_jump`, behavior settings): a stuck bot waits and then teleports to the next path point, and a
car hit only throws it. With the cvar on, a stuck bot jumps first and a hit adds a jump. An actor leaving a car is
put at a spot free for its whole body, never inside the car.

## Weapons and teams

- Only actors whose weapon roll passed (`getting_weapon_chance`, 10% of citizens) are armed.
- An unarmed actor in `fear` / `run_from_danger` runs to a free weapon within 500 units (`pick_up_weapon`) and
  fights with it. It was spawned without a weapon, so it always shoots with `WEAPON_PROFICIENCY_POOR`
  (`actor.novice_shooter`, `bgNPC.Combat.ApplyWeaponSkill`). The same goes for an HL2 NPC that picked a weapon
  up by its engine AI.
- Actors of one team never damage or answer each other. `bgn_team_damage 1` lets the damage through,
  they still don't react to it.
- **Offenders** (`systems/sv_offender.lua`): a civilian (`residents`, not `police`) who rams a police car (a hit with damage) or kills a `residents` actor
  (a citizen, an officer, a medic) loses `residents` and gets the team `offenders`. Only this actor's `data.team`
  changes (every actor holds its own copy of the config), so the team immunity no longer covers it. If wanted mode
  is on and someone saw the kill, it is added to the wanted list: the residents take it as an enemy and react
  as to a wanted player (arrest, defense, fear, calling the police). It then runs from the nearest resident
  (`fear`) or, with an officer in sight and `bgn_arrest_mode` on, gives up (40%, `arrest_surrender`). The team is
  not restored when the wanted time runs out. Not in peaceful mode.
- **Shared enemies** (`systems/sv_enemy_sharing.lua`, `bgn_enemy_share_period`, default 2 s, `0` = off): an actor
  with enemies (not in `fear`, not in a vehicle) tells every teammate within 1000 units that sees it (a trace from
  the teammate's eyes to the actor) about the enemies the teammate does not know. A teammate in a car is skipped,
  except an officer: it gets the enemy and steps out or fires from the car (`modules/dv/sv_move_to_target.lua`). A teammate in a calm state
  switches to its `GetReactionForProtect` reaction; a busy one only gets the enemy. This keeps the others from
  walking around while an officer already shoots at a player who is not wanted yet.
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
  Any state change re-reads the facts at once, so an action that finished with its effects (`take_cover` sets
  `in_cover`, `call_backup` sets `backup_called`) moves the plan on instead of failing. An action whose state is
  already running (also after a replan) counts as entered. An action that fails (its state ends or redirects on its
  own without its effects) is blocked for 5 s, then the plan is made again. A `guarded` state that refuses to stop
  (an officer holding an `arrest`) only makes the plan wait; nothing is blocked.
- **Reactions** (`GetReactionForDamage` / `GetReactionForProtect`) take the state of the plan's first action. An
  action with `prepare` (`surrender`) is never run while a reaction is picked: the config roll is returned and the
  next brain update starts the action.
- **Chains.** Fighting an armed enemy costs more out of cover, and for the police without backup, so the plans are
  `take_cover → attack` and, for the police, `call_backup → take_cover → attack`:
  - `take_cover`: runs to the nearest nav point within 1000 units the enemy can't see at crouch height
    (`bgNPC.FindCover`), crouches 3 s, then fights 10 s (`in_cover`) before the next cover. No cover found: it
    fights.
  - `call_backup`: the officer calls on the radio (`police_backup`); up to 3 free officers on foot within 4000
    units take the enemy and come. Once per officer per minute.
  - `surrender`: a hurt gangster (`low_health`) facing the police gives up (goal `give_up`, above hiding) when an
    officer within 700 units sees it and `bgn_arrest_mode` is on: it says `give_up`, the officer (stepping out of
    its car if needed) arrests it through `ArrestModule:Surrender` (`systems/arrest`). The plan never interrupts
    `arrest_surrender`.
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
Some deaths cannot be saved: explosions, vehicle hits and overkill damage always, any other death with the chance
`bgn_medic_hopeless_chance` (25 %; Behavior > Medics). For those the medic still comes and kneels over the body, but
instead of reviving says `medic_cannot_save` and leaves (`call.verdict`); only then does an officer take the body.
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

## Gangs

Two street gangs replace the plain `gangster` actor (kept disabled as their config base): **Black Raven**
(`gangster_crows`, team `gang_crows`) and **Red Wolf** (`gangster_wolves`, team `gang_wolves`)
(`config/actors/sh_gangs.lua`). Both keep the team `bandits` (police reactions, carjacking). A member is light
(35 % are heavy, `heavy_chance`): light members wear HL2 citizen clothes and carry a pistol, heavy ones wear rebel gear
and carry an SMG or a rifle (`systems/npcs/sv_gang_models.lua`). The clothes sheet of the model is replaced by the
gang's recolor with `SetSubMaterial` (`materials/background_npcs/gangs/<gang>/<class>_<sex>`); the class is read from
the model, so it survives revival and leaving a car. The recolors are made from the game's own textures by
`tools/make_gang_skins.py` (needs `vpk`, `srctools`, `pillow`, `numpy`); the game files are not shipped.

**Fight rosters** (`systems/sv_fight_roster.lua`). Gang members help only their own gang, and a fight cannot grow
without bound. When the first member of a gang takes an enemy (is attacked, sees a crime), the roster of that fight
is formed at once: the initiator plus the nearest living members of the same gang within 1000 units, each joining
with `bgn_gang_help_chance` percent (default 1), 2-6 members in total (random per fight). The chosen ones join
immediately; every other member of the gang is refused that enemy and ignores calls for help. The police and the
player therefore fight a capped group. Members of different gangs are not teammates (`Actor:HasTeam`), so a gang
never helps the other one. Calm members of rival gangs within 700 units sight of each other start a fight with
`bgn_gang_war_chance` percent per 10 seconds (default 0.5, `0` disables); if the police or a player step in, each
gang fights them (and each other) with its own roster. Actors outside gangs are not affected.

A calm gang member walks in a pack (`systems/npcs/sv_gang_pack.lua`, used by the `walk` state): of the walking
members of the same gang within 1500 units the one with the lowest entity index is the leader and picks its
destination as usual, the others walk to a spot 100-250 units from it and recheck every 8 seconds.

Orphan bodies: `Actor:RemoveActor` leaves the entity to the engine, right for a death only. A body that lost its
actor while still alive (no label, no brain) is removed after 3 seconds (`spawner/sv_actor_remover.lua`, with
`developer 1` the console names its type and last state). A medic marked `eternal` for a call is released together
with the call, so it no longer escapes the limit and the remover.

A calm gang member walks in a pack (`systems/npcs/sv_gang_pack.lua`, used by the `walk` state): of the walking
members of the same gang within 1500 units the one with the lowest entity index is the leader and picks its
destination as usual, the others walk to a spot 100-250 units from it and recheck every 8 seconds.

Orphan bodies: `Actor:RemoveActor` leaves the entity to the engine, right for a death only. A body that lost its
actor while still alive (no label, no brain) is removed after 3 seconds (`spawner/sv_actor_remover.lua`, with
`developer 1` the console names its type and last state). A medic marked `eternal` for a call is released together
with the call, so it no longer escapes the limit and the remover.

Calling the police is skipped when at least one living officer already has the target as an enemy or a target
(`bgNPC.PoliceKnows`, `calling_police` state and the GOAP `police_called` sensor).

## Delay between skirmishes

`bgn_fight_cooldown` (Behavior > AI, 0-120 s, default 60, `0` = off, the old behavior). With a delay, the first `defense`
reaction of the `at_protect` table (actors protecting their own) opens a window of that many seconds around the
place (2500 units). While it lasts, protecting against **another** attacker in that area is ignored: the actor takes
the `ignore` reaction and a call for help, enemy sharing or a witnessed hit adds no enemy to it. The police are never
delayed, also an officer driving past in a car. Actors joining the skirmish that
opened the window (same attacker), fights already going, places outside the area and the time after the window are
not affected. A player, or an NPC / NextBot of another mod that is not one of our actors, as the attacker is never blocked (`systems/sv_fight_cooldown.lua`).

## Police at a body

Every actor death outside a vehicle also leaves a body for 60 s (`brain/fsm/states/sv_police_inspect_body.lua`).
The nearest officer within 2000 units who walks or idles without enemies takes it (state `police_inspect_body`):
runs to the body when it is farther than 600 units (walks when closer), says `police_body_arrive`, crouches over it, reports it on the radio (`police_body_report`) and writes it down
(`police_body_notes`), 5 s each, then goes on patrolling. Bodies from a shoot-out are taken once the officers
calm down; a body revived by a medic is dropped. A body a medic is on the way to waits until the medic has revived it or declared it hopeless.

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

Police dismount when a living enemy (or their current arrest target) is within 800 units or their vehicle has at most 20% health remaining. They stay seated while that enemy is driving away: the dismount waits until the enemy's car has stood still for about 6 seconds or the enemy gets out.

A police car chasing a wanted player that falls more than 2800 units behind and is out of every player's view is not culled: its crew steps out and the car is rebuilt (a fresh car, the same actors and enemies) on a hidden road point 600-2200 units from the player, at most once per 8 seconds per player and only while fewer than `1 + wanted level` chasing cars are close. See `spawner/sv_police_pursuit.lua`. Spawn points also keep clear of the road ahead of a moving player.
Simfphys health uses `GetCurHealth()` and `GetMaxHealth()`; vehicles without a positive maximum health do
not trigger the damage condition. Neutral players do not trigger dismounts. Hits use the normal actor damage reactions, so a real attack can create an enemy and make police dismount. Direct vehicle removal removes its crew; forced ejection still requires a safe exit.

Actors and Decent Vehicle cars; the state `go_to_police_car` (no longer police only) runs to the car and gets in.

- **Back to the car** (`modules/dv/sv_return_to_vehicle.lua`, every 2 s): an actor within 1000 units of an allowed car returns when no enemy is within 1500 units. Neutral living players also delay civilians, but not police. Former crew may take free passenger seats after their driver returns. Police do not reboard critically damaged cars.
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
Former crew may also rejoin an occupied car if a passenger seat is free. A police vehicle keeps its police designation even after a group change; only police actors may drive or ride in it. Players can still take an empty police car.
`VEHICLE:CanSeize`: a car of another group, empty or driven by an actor (never a player), not driven by a
teammate. Only the police and bandits seize.

Boarding removes the physical NPC/NextBot and binds the same logical actor to a DV anim entity; exiting recreates its original body and equipment. Exit placement prefers the closest model exit or the side and row of its own seat, checking full body clearance and overlap even with non-colliding actors. If all positions are blocked, it stays aboard. Seated hits retain the attacker and notify nearby witnesses through the normal damage hooks. Witness traces exclude their own chassis/seat and recognize another occupant's chassis; walls still block sight.

BGN traffic can plan bounded forward/reverse maneuvers around blockers and, after repeated failures, try another accessible road segment. Red lights, scheduled stops and taxi waits suppress recovery. Cars honk briefly only at an entity blocking their forward sensor. These changes apply to BGN-created vehicles; DV remains required. See [traffic checks and limitations](testing.md#dv-traffic-developer-checks).


## Related systems

[Gangs](gangs.md) limit fight rosters and new protection events; direct self-defense remains. [Medics and bodies](medics.md) own calls/verdicts/cleanup. [Wanted](wanted.md) and [arrest](arrest.md) own pursuit/surrender. Stuck NextBots choose nearby free navigation space excluding vehicles; custom-chair placement uses seat height.
