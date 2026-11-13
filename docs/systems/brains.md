# Actor brains

An actor is split into an **actor** (data and rules), a **body** (`actor.body`: everything that talks to the
engine entity: movement, schedules, relationships, weapons, animation) and a **brain** (`actor.brain`: decisions).
Bodies and brains exist on the server only.

## Pursuing an occluded target

SERVER keeps a stable combat target through `GetEnemy`: a recent direct attacker takes priority, followed by the siege/squad target and the previous valid enemy. Perception checks every enemy, so a nearer hidden enemy cannot prevent observation of another. Ordinary hidden positions are never refreshed from the current entity position. Teammates, radio backup and siege participants receive the last observed position with its original timestamp; sharing does not renew a sighting.

When the target is hidden, `defense` advances to that remembered position without a minimum firing distance. A hidden-target squad uses a column anchored at the remembered position, without the visible-target 550-unit gap. Cover requires line of sight and ends when sight is lost. With no known position, the actor stops rather than navigating to the hidden entity's current position.

A fixed 1000-unit combat radius (SERVER, no setting) protects a living combat actor from ordinary population removal/recycling and NextBot unstuck teleports while any living known enemy is within that radius, inclusive. It also gates the final respawn operation after asynchronous spawn search. Sieges remain busy until finished. Outside the radius the ordinary unseen timeout and eligibility rules apply. Death, admin cleanup and disabling the addon/type retain their separate paths.

<a id="lethal-weapons"></a>

## Reaction to weapons in hands

`bgn_react_to_lethal_weapon` is a SERVER setting, **0 by default**. When enabled, once per second living
`residents`/`police` actors inspect players, NPCs and NextBots, including BGN actors. A target holding a
learned lethal weapon must be within **800 units inclusive**, in front of the observer's eyes (FOV,
including NextBot observers), and visible through LOS. Shared-team targets, existing enemies, ignored
players and players in friend mode are skipped; peaceful mode disables reactions.

The actor picks `GetReactionForDamage(target)` (`at_damage`), as when hurt. `ignore`/`none` adds no enemy.
Otherwise it requests `AddEnemy(target, reaction)`; if accepted, it stores the reaction and, while calm,
clears its targets and enters that state. Busy actors retain their state. Enemy-controller, team, arrest,
medic and addon-hook restrictions still apply. This starts the ordinary FSM/GOAP behavior without
fabricating damage, conflict records or a wanted assignment. Later police calls and enemy sharing use
their ordinary rules; the 800-unit/FOV gate applies to initial detection, not those separate systems.
Holstering the weapon or disabling the setting does not clear enemies; ordinary forgetting still applies.

Learning is always active, including with the checkbox off. On `BGN_OnKilledActor`, SERVER checks the
attacker's callable `GetActiveWeapon`, validates its returned entity and stores its `GetClass()`. The
last damage must identify that same attacker. Explosion/vehicle damage and kills by a player inside a
vehicle are excluded. No prefilled weapon list is supplied; the first qualifying kill teaches a class.
Classification uses the weapon held at death, not the projectile/inflictor's class.

`systems/sv_lethal_weapons.lua` reads `data/background_npcs/lethal_weapons.json` once into a persistent
SERVER cache, retained through script reloads. The JSON object maps class names to `true`; all maps share
the file. Each new class updates the cache and rewrites the full object; duplicate kills and detection
perform no file reads/writes. CLIENT receives only the setting through the existing cvar synchronization.
An invalid file is reported and preserved without overwriting for that cache's lifetime; a write failure
is reported while the learned class remains in memory. Offline edits take effect on the next server/map
start. Isolated tests: `tests/sv_lethal_weapons.lua` via `bgn_selftest`.

## Donor animations

`bgNPC.Animator` plays gestures using a server-owned invisible donor model and clientside bone-merged copies of the character and its weapon. It requires compatible skeletons. Ordinary static sequences still play directly on the actor's body.

The server checks active animation viewers every 0.25 seconds and sends the current animation when a ready player enters its PVS, including late connections. One-shot animations retain their original deadline; loops last until stopped. Stopping releases an NPC schedule frozen by Animator if it is still current and no static actor animation owns the body. The client copies skin, bodygroups, color, material, submaterials and model scale at animation start; subsequent appearance changes are not tracked. The `dance` state starts its animation after the previous state's animation is reset.

SERVER `Animator.Play` normally requires a PVS viewer at startup. `settings.require_pvs = false` permits a
gameplay animation without one; room sieges use it so a closed visibility portal does not prevent deployment.
Late viewers still receive the remaining animation with its original deadline.

## Bodies

`bgn_actor_body npc|nextbot` (default `npc`; the old value `auto` is the same as `npc`). By default actors are real HL2 NPCs (`NPCBody`), like in the old versions: other addons (model replacers, ragdoll and death mods, Bio-Annihilation 2, Followers) see only real NPCs (`IsNPC`, `OnNPCKilled`). With `nextbot`, on maps with a NavMesh, actors of the HL2 classes
`npc_citizen`, `npc_metropolice` and `npc_combine_s` spawn as `bgn_nextbot` (NextBot, `NextBotBody`), and such addons may not work with them. The NextBot walks with the NavMesh path follower, opens doors (the ones allowed, see navigation.md "Doors"), gets unstuck, and
shoots or hits with a real HL2 weapon held in its hand (players can't pick it up while the bot is alive; it drops
the weapon on death, like an HL2 NPC). Shots start at the bot's right hand. The config `weapon_skill` works for
NextBots too: the spread scales like the HL2 NPC cone (poor ×1.4, average ×1, good ×0.67, very good ×0.33,
perfect ×0.2). HL2 NPCs that the bot hates are told to hate it back.


In `nextbot` mode, SERVER counts each foreign HL2 NPC's dispositions towards all server players and applies the most frequent disposition (`D_HT`, `D_FR`, `D_LI`, `D_NU` or `D_ER`) to nearby BGN NextBot bodies. Ties and an empty player list resolve to `D_NU`. `systems/sv_nextbot_hostility.lua` refreshes this once per second within 2500 units, including changes away from hostility. Initialization uses the same vote for NextBot targets. Foreign NPC dispositions towards ordinary HL2 NPC actor bodies are preserved; detection reads their direct disposition towards the actor (see [wanted and conflicts](wanted.md#conflict-memory-and-witnesses)). No hidden probe NPCs are created. HL2 NPC senses detect `bgn_nextbot` through `FL_OBJECT`, set before engine registration in `Initialize`. The periodic update is skipped in peaceful mode and with `bgn_ignore_another_npc`.

After updating from the probe-based implementation, reload the map to clear legacy probes. `bgn_selftest` includes the player-disposition vote checks; mixed-player votes are pure logic tests.

Without a weapon some models (Combine soldiers) have no plain idle/walk/run and would T-pose, so the bot falls
back to the armed ones (`ACT_IDLE_SMG1`, `ACT_WALK_RIFLE`, `ACT_RUN_RIFLE`, then the pistol ones). Jumps are off by
default (`bgn_nextbot_jump`, behavior settings): outside the protected combat radius a stuck bot waits and then teleports to the next path point, and a
car hit only throws it. With the cvar on, a stuck bot jumps first and a hit adds a jump. An actor leaving a car is
put at a spot free for its whole body, never inside the car.

## Weapons and teams

- Only actors whose weapon roll passed (`getting_weapon_chance`, 10% of citizens) are armed.
- An unarmed actor in `fear` / `run_from_danger` runs to a free weapon within 500 units (`pick_up_weapon`) and
  fights with it. It was spawned without a weapon, so it always shoots with `WEAPON_PROFICIENCY_POOR`
  (`actor.novice_shooter`, `bgNPC.Combat.ApplyWeaponSkill`). The same goes for an HL2 NPC that picked a weapon
  up by its engine AI.
- A direct attacker with no shared team is added as an enemy on the first hit, even during an existing fight; reaction hooks can still cancel it.
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
  walking around while an officer already shoots at a player who is not wanted yet. Gang exceptions (all visible allies, without a distance cap or reaction roll) are described under [gangs](gangs.md).
- A wanted actor (`Actor:IsWanted`, wanted is lost by NPCs exactly like by players) hides: a `defense` reaction
  turns into `retreat`, which fights back only when the enemy is within 190 units; `defense` returns to `retreat`
  when the enemy is over 300 units away and the actor has under 50% of its max health.
  **Witness check** (same timer): a calm actor not in a vehicle that sees a teammate in `fear`, `run_from_danger` or `dyspnea_danger` with enemies,
  and itself sees one of that teammate's enemies within 1000 units, takes the enemy too and reacts like a calm one that
  was asked for help. Fights and other danger states do not count. The scan starts from scared actors within 2500
  units of a living player, so no traces are spent far from players. It needs both lines of sight, so a scared actor's panic spreads only as far as eyes reach.
  `AddEnemy` guards (arrest protection, ignored entities, peaceful mode) still apply.

Prop-chair seating (`sit_to_chair`) uses the configured chair models and offsets. The route handles the distant
approach; within 300 units the body finishes moving to the chair, and seating begins within 60 units.
This applies to both HL2 NPC and NextBot bodies. Custom map seats use `sit_to_chair_2`.

## Choosing a brain

`bgn_brain auto|fsm|goap` (default `fsm`, the classic brain). In `auto` an actor gets the brain from its config field
`brain = 'fsm' | 'goap'`, otherwise GOAP when the config has `weapons`, otherwise FSM.

## FSM brain

Runs the `update` callback of the current state (`bgNPC.States`), and picks a random state from `at_random`
when the actor has none. Reactions to damage and threats are random picks from `at_damage` / `at_protect`.

## GOAP brain

Plans only the fight; everything else is the FSM brain. The config reactions (`at_damage` / `at_protect`, a
weighted random pick, the same as in FSM) decide whether the actor fights at all: an officer that rolled `arrest`
arrests, a citizen that rolled `fear` runs. The plan takes over once the actor is in `defense` (or `retreat`, the
`defense` of a wanted actor) and keeps it until the enemies are gone or the state leaves the plan's own states
(the FSM ended the fight, an arrest, a calm state); it never pulls the actor back into a fight. Having an enemy
alone (shared enemies, a wanted target) does not start one. Earlier 2.3.1 builds also picked the reactions from
the plan and attacked whenever the actor had an enemy, which made fights much more frequent than with FSM.

- **Facts** are measured by sensors once per second (and right after damage or a new enemy):
  `has_enemy`, `armed`, `is_police`, `low_health`, `enemy_close`, `enemy_armed`, `enemy_police`, `police_called`,
  `wanted`, `in_cover`, `backup_called`, `outnumbered`, `surrendered`, `desperate`, `can_hold_door`, `enemy_bracing`, `can_siege`.
  `outnumbered` is police only: two or more
  living enemies of the officer within 2000 units, and more of them than living officers there (itself included).
- **Actions** run states: `attack` → `defense`, `flee` → `fear`, `call_police` → `calling_police`,
  `hide` → `retreat` (wanted actors only), `take_cover` → `take_cover`, `call_backup` → `call_backup`,
  `surrender` → `arrest_surrender`, `hold_door` → `hold_door`, `breach_door` → `breach_door`, `siege` → `siege`.
  An actor can only use actions whose state appears in its `at_damage` / `at_protect` config with a weight
  above zero, except actions registered with `always = true` (`hide`, `take_cover`, `call_backup`, `surrender`,
  `hold_door`, `breach_door`, `siege`).
  A trait action is rolled once per actor: `call_police` with its config share (20 of 100 → 20%). `surrender` is
  not a trait: it is rolled at every attempt (8%, see below).
  An action stays running while its state moves on to a follow-up (`also`, e.g. `fear` → `run_from_danger`).
  Any state change re-reads the facts at once, so an action that finished with its effects (`take_cover` sets
  `in_cover`, `call_backup` sets `backup_called`) moves the plan on instead of failing. An action whose state is
  already running (also after a replan) counts as entered. An action whose state moves to another action's state
  without its effects is blocked for 5 s, then the plan is made again; a state outside the plan ends the fight.
- **Reactions** (`GetReactionForDamage` / `GetReactionForProtect`) are the config roll, as in FSM. In `fear` an
  armed actor switches to `defense` (as in FSM) unless the plan itself sent it to flee.
- **Chains.** Fighting an armed enemy or, for an outnumbered officer, a crowd costs more out of cover, and an
  outnumbered officer without backup pays more again, so the plans are `take_cover → attack` and, for an
  outnumbered officer, `take_cover → call_backup → attack` (no cover found: `call_backup → attack` in the open):
  - `take_cover`: runs to the nearest nav point within 1000 units the enemy can't see at crouch height
    (`bgNPC.FindCover`), crouches 3 s, then fights 10 s (`in_cover`) before the next cover. No cover found: it
    fights.
  - `call_backup`: the outnumbered officer calls on the radio (`police_backup`); up to 3 free officers on foot
    within 4000 units take the enemy and come, and with `bgn_enable_wanted_mode` on every enemy of the officer
    (except police) becomes wanted, which sends all the police after it. Once per officer per minute.
    Earlier 2.3.1 builds called backup against any armed enemy, without the wanted status.
  - `surrender`: a hurt gangster (`low_health`) facing the police gives up (goal `give_up`, above hiding) when an
    officer within 700 units sees it and `bgn_arrest_mode` is on, and only with an 8% roll per attempt (a failed roll
    blocks the action for 5 s, so the roll repeats every few seconds while the conditions hold): it says `give_up`, the officer (stepping out of
    its car if needed) arrests it through `ArrestModule:Surrender` (`systems/arrest`). The plan never interrupts
    `arrest_surrender`.
- Arrests are not planned: the arrest system (`systems/arrest`, `ArrestModule:CanArrest`) owns them, and it
  only works on police without enemies.
- **Goals** (`eliminate`, `survive`, `report`, `hide`, `give_up`, `shelter`) get a priority from the actor's **set**:
  `police`, `gangster` or `citizen` (by team, or the config field `goap_set`). `hide` outranks ordinary combat
  while wanted; an available door shelter has priority 30 when desperate.
  A citizen reports (calls the police) an enemy farther than 700 units even when it is armed, unless it is hurt
  (then it runs) or armed itself (then it fights).
- The planner (A* over fact bit masks) returns the cheapest action chain for the top goal. Plans are cached.
- `ignore` in a reaction table keeps its random chance.

Debug: `bgn_goap_debug` prints the set, goal, plan and facts of the actor you look at.

### Door shelter and breaching

These are server-driven actions for both NPC and NextBot bodies, not random scenic poses. Any non-police GOAP actor
already fighting or fleeing can seek an open door when below 35% health, unarmed against an armed enemy,
or facing more living enemies within 1000 units than itself plus nearby armed teammates. An ordinary flee
reaction only borrows GOAP to seek shelter; it does not become an attack if no door fits or shelter ends.

`hold_door` searches within 400 units for an unlocked, unclaimed rotating door. It uses the leaf's **closed**
geometry, moves to the side away from the enemy, stays outside the swing while closing, temporarily locks
the door, then steps up and plays a supported `doorbracer_*` sequence. Approaching takes at most 10 s,
closing/positioning 4 s, holding 12 s; another attempt waits 20 s. The action ends if the enemy dies, reaches
the same side, disappears from the actor's enemies, or the door is removed. It releases its lock on exit.
Models are never replaced to obtain an animation: without a supported brace sequence the action is unavailable.
Supported doors are upright, unparented `prop_door_rotating` and `func_door_rotating`; sliding and moving-parent
doors are skipped. Physics/world obstructions may prevent reaching or closing a door, ending the attempt.

Police with an enemy actively holding the other side can choose `breach_door` within 800 units. They approach,
kick (when the model has a suitable sequence), and open the door at 900 degrees/s, restoring its previous speed
after 0.4 s. This only releases the holding actor's temporary lock; it does not force arbitrary map-locked doors.

The holder enters `knocked_down`: a temporary server ragdoll receives the impulse, while the **same** original
NPC/NextBot entity and actor/UID remain registered, hidden, non-solid and unable to move, shoot or board a car.
The breach and physics contacts add no damage. Shots at the ragdoll are forwarded to the actor; lethal damage
uses ordinary death/corpse handling. After 3 s it looks for a full standing hull within 96 units of the body;
if blocked, it stays down and retries. On recovery it restores visibility, collision, equipment and the previous
combat/flee behavior, keeping current health. Removing the temporary ragdoll also removes its hidden actor.
Clients only display the server state/body; they do not choose actions or control doors.

### Sieging a single-exit room

SERVER GOAP fighters of class `npc_metropolice` or `npc_combine_s` can choose `siege` for an enemy last seen
within 30 s, at a doorway within 1000 units. Enemy memory stores the last visible position; the tactic does not
aim at a continuously updated position through walls. It requires a loaded NavMesh, including when pedestrian
routes use the custom provider. Removing the doorway connections must leave a roofed pocket containing the
remembered position, with no alternate connection around the cut. Adjacent door leaves count as one exit;
narrow walled NavMesh passages without door entities are also considered if door candidates do not prove a pocket.
If the target vanished within 300 units of a doorway and the remembered side proves no pocket, the far side of that doorway is tried as the pocket. An actor already inside the pocket never joins; a member that enters it leaves the siege for `defense` without cancelling the others.
Searches are bounded to 128 areas, 900 units and one floor (80-unit height tolerance); ladders, unknown geometry,
missing navigation or an unproven pocket decline the tactic. The scenic indoor check alone does not prove one exit.
Incomplete NavMeshes can omit real escapes such as windows or jumps.

One reservation controls the enemy/entrance. Up to five members of the initiating squad occupy separated
positions outside it; other armed fighting teammates within 2000 units receive spaced waiting positions at
least 650 units away (34-unit arrival tolerance). Existing squad membership is captured before the normal squad
rebuild excludes siege participants. Without a current squad, the nearest eligible allies fill the five places.
Only actors with a supported waiting animation join. Positioning has a 15 s limit; the 12 s silent wait starts
after the front group is positioned and rear participants have withdrawn. Both NPC and NextBot bodies suppress
ordinary shooting and BGN voice lines during the tactic. Followers can execute the state with an FSM brain;
the initiating fighter requires GOAP.

Narrow corridors fall back to separated positions along the passage instead of side positions. Members that
cannot fit near the entrance try the rear positions; if a close eligible reinforcement cannot withdraw, the
attempt ends rather than leaving an uncoordinated group crowding the active siege.

After waiting, closed rotating doors are kicked with 35% probability or opened normally. An unsupported kick
falls back to a supported opening gesture, and vice versa; without either animation the doorway is unavailable.
Combine models can use their gun strike to breach. Existing door-opening/locked-door settings and held-door
reservations still apply. The operator steps outside the swing and retries opening once if necessary. Doors
must be fully open before deployment. Their automatic return delay is temporarily suspended and restored on
exit; a previously locked door is relocked after the attempt. Door entities are preserved.

The single operator deploys **one** `npc_manhack` (`npc_metropolice`, requires `deploy`) or **one**
`npc_grenade_frag` (`npc_combine_s`, requires `grenThrow`). The selected model is never replaced.
Existing donor animation playback prevents native NPC animation events from creating duplicate weapons.
The grenade uses a traced ballistic path, a 3.5 s fuse and a blast-clearance check for non-enemy actors/players.
The manhack gets a checked entry direction and two seconds of native directed flight, then ordinary AI;
it is hostile (`D_HT`) to every current enemy of the operator, friendly (`D_LI`) to the operator's team, neutral (`D_NU`) to everyone else, never becomes wanted, is skipped by the relationship and NextBot-hostility updaters that would override its relations, and removes itself after 30 s. Weapon damage is attributed to its operator.
The operator opens the door and releases the weapon from the same spot: the throw starts while the leaf is still
swinging (a retry window of 1.5 s covers a blocked path), and the operator then returns to its slot during the
fuse. The operator is not part of the blast-clearance check. The group holds another 6 s after deployment. The whole attempt is limited to 50 s and shares a 60 s target
cooldown. Damage to a participant, loss of an enemy/operator, leaving the pocket, interruption by arrest or
another state, map cleanup or a navigation reload ends it and restores body control. Clients display the
state/animations; they do not choose the tactic or spawn weapons.

### Hostage negotiation

`systems/sv_negotiation.lua` (SERVER). A frightened non-police actor within 300 units of a player target that stands
closer to the officer than the target is a hostage: the target hides behind it, so approaching from behind does not
count. Every officer that sees such a shield holds fire (engine NPCs lose `CAP_USE_WEAPONS`, NextBots skip
`UpdateCombat`), the first one offers to surrender and warns 5 s before the 20 s deadline. The talks end quietly when
the shield stays gone for 3 s; they fail on the deadline or when the player kills anyone. After a failure the officers shoot
again and the player is not offered talks until he is arrested, drops a wanted level, dies or 120 s pass.
Negotiation with NPC targets is a separate story scenario and is not implemented.

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
form squads of up to 5. The healthiest leads, its selected combat enemy becomes the target of every member.
Formations face the target: `column` when nobody sees it, `wedge` with 4+ healthy members, `line` otherwise.
The healthiest stand in front, the wounded (< 40% health) form a rear rank. `defense` moves a member to
`actor.squad.slot`; `bgNPC.Squads.list` holds the current squads.

## LOD

Actors far from players update less often (`bgn_lod_near_radius`); idle unarmed actors out of range sleep
(`bgn_disable_logic_radius`). Hook: `BGN_ActorLODChanged(actor, lod)` (1 near, 2 far, 3 dormant).

Distant unseen unarmed actors on foot now alternate pauses and active windows instead of remaining frozen. SERVER settings (Performance and classic Optimization): `bgn_logic_pause` = 2 s (0 disables pauses), `bgn_logic_active` = 1 s (minimum 0.1), `bgn_logic_stagger` = 0.25 s per UID. During active windows both engine movement and the brain resume; brain interval is 0.2 s. Phase is `(time - UID * stagger) modulo (pause + active)`, stable across list reordering. Windows overlap and phases wrap in larger crowds; this spreads transitions, not exclusive execution. Close/in-view actors, armed actors and vehicle occupants retain continuous simulation. Damage/enemy events immediately wake an actor for at least one second. LOD 3 now means intermittent simulation, not permanent sleep. Existing distance thresholds are retained; with near radius 2500 and disable radius 500, off-view actors beyond 2500 enter this cycle. Timings are observed on actor scheduler passes, not exact real-time deadlines.

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
Medics only take as enemies those who hurt them. Nobody comes for an actor killed by the police (team `police`), nor for one whose death no living ally of the victim saw.

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

**Gang support and walking.** Members walk in packs of up to three; all visible same-gang allies receive a threat without a chance roll or roster cap, including late arrivals. Combat support is independent of walking packs. See [gangs](gangs.md) for visibility, sharing interval and war rules.

Orphan bodies: `Actor:RemoveActor` leaves the entity to the engine, right for a death only. Every 2 s an NPC or
NextBot that is an actor body (`BGN_ACTOR_OBJECT`, or `bgn_npc_class` from the spawner) without a live registered
actor is removed after 3 seconds, even with `bgn_enable 0` (`spawner/sv_actor_remover.lua`, with `developer 1` the
console names its class, health, type and last state). Health is not checked: an NPC killed while the LOD had its
think turned off, or frozen by the animator, never finishes dying and stands with 0 health, frozen, without a label;
the old check (alive bodies only) left those on the map for good. An actor removed in its first tick is no longer
registered afterwards (it kept a slot of the type limit). A medic marked `eternal` for a call is released together
with the call, so it no longer escapes the limit and the remover.

Calling the police is skipped when the target is already wanted, or at least one living officer has it as an enemy or a target
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
calm down; an enemy that appears during the inspection ends it at once and the officer reacts as to an attack. Bodies within 150 units are one scene with one officer. A body revived by a medic is dropped. A body a medic is on the way to waits until the medic has revived it or declared it hopeless.

## Onlookers

Every actor death outside a vehicle is also an incident for 45 s (`brain/fsm/states/sv_watch_incident.lua`).
From 5 s after it, calm civilians walking or idling within 1500 units come one by one (35% per 2 s check, up to 4):
they stand 150-280 units from the spot on their side, stare (`LineIdle*`), half of them say a `watch_incident` line,
and go on after 12-25 s. A gunshot scares them like any calm actor; two of them may start a conversation.
When the medics revive the actor (`BGN_ActorRevived`), the incident ends: no new onlookers come and those already there go on.

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

[Gangs](gangs.md) walk in packs of three and support visible allies; direct self-defense remains. [Medics and bodies](medics.md) own calls/verdicts/cleanup. [Wanted](wanted.md) and [arrest](arrest.md) own pursuit/surrender. Stuck NextBots choose nearby free navigation space excluding vehicles; custom-chair placement uses seat height.

## Police weapon choice and witnessed harm

See [police weapon choice and harm memory](arrest.md#police-weapon-choice-and-witnessed-harm).

## NextBot pistol cadence

The stock pistol now fires groups of 1–3 individual shots, approximately 0.2 s apart, followed by a 0.45–0.8 s rest. These are separate, visibility/friendly-fire-checked shots, not multiple bullets in one attack. The 18-round magazine keeps the 1.8 s reload pause. Burst state resets on weapon/target changes and reload; other weapon profiles and scripted-weapon fallback remain unchanged. Combat checks quantize the intended intervals to engine ticks.

`python tools/test_police_force.py` checks witnessed distinct counts, thresholds, memory/reset/rebind, vehicle damage and pistol cadence. Live single-player checks compare native HL2 and NextBot shots and inspect arrest weapon retention; multiplayer and third-party weapon bases require separate verification.

Movement updates run every 0.1 s for near actors and every 0.25 s for far or dormant ones (the node arrival radius is 150 units).
