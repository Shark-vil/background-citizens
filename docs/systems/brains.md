# Actor brains

An actor is split into an **actor** (data and rules), a **body** (`actor.body`: everything that talks to the
engine entity: movement, schedules, relationships, weapons, animation) and a **brain** (`actor.brain`: decisions).
Bodies and brains exist on the server only.

## Bodies

`bgn_actor_body auto|npc|nextbot` (default `auto`). On maps with a NavMesh, actors of the HL2 classes
`npc_citizen`, `npc_metropolice` and `npc_combine_s` spawn as `bgn_nextbot` (NextBot, `NextBotBody`), otherwise
as HL2 NPCs (`NPCBody`). The NextBot walks with the NavMesh path follower, opens doors, gets unstuck, and
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

`bgn_brain auto|fsm|goap` (default `auto`). In `auto` an actor gets the brain from its config field
`brain = 'fsm' | 'goap'`, otherwise GOAP when the config has `weapons`, otherwise FSM.

## FSM brain

Runs the `update` callback of the current state (`bgNPC.States`), and picks a random state from `at_random`
when the actor has none. Reactions to damage and threats are random picks from `at_damage` / `at_protect`.

## GOAP brain

Used while the actor has enemies; without enemies it behaves like the FSM brain.

- **Facts** are measured by sensors once per second (and right after damage or a new enemy):
  `has_enemy`, `armed`, `is_police`, `low_health`, `enemy_close`, `enemy_armed`, `police_called`, `wanted`.
- **Actions** run existing states: `attack` → `defense`, `flee` → `fear`, `call_police` → `calling_police`,
  `hide` → `retreat` (wanted actors only).
  An actor can only use actions whose state appears in its `at_damage` / `at_protect` config with a weight
  above zero, except actions registered with `always = true` (`hide`). `call_police` is a trait: each actor gets it once with its config share (20 of 100 → 20%).
  An action stays running while its state moves on to a follow-up (`also`, e.g. `fear` → `run_from_danger`).
- Arrests are not planned: the arrest system (`systems/arrest`, `ArrestModule:CanArrest`) owns them, and it
  only works on police without enemies.
- **Goals** (`eliminate`, `survive`, `report`, `hide`) get a priority from the actor's **set**: `police`,
  `gangster` or `citizen` (by team, or the config field `goap_set`). `hide` outranks the rest while wanted.
- The planner (A* over fact bit masks) returns the cheapest action chain for the top goal. Plans are cached.
- `ignore` in a reaction table keeps its random chance.

Debug: `bgn_goap_debug` prints the set, goal, plan and facts of the actor you look at.

### Extending

```lua
bgNPC.GOAP.RegisterAction('take_cover', {
	state = 'retreat',                      -- a registered state that performs the action
	pre = { has_enemy = true, enemy_armed = true },
	effects = { safe = true },
	cost = function(ws) return 1 end,       -- number or function(world_state)
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

Actor type `medic` (`config/actors/sh_medic.lua`, limit 2) is never spawned by the regular spawner. Every actor
death outside a vehicle is a call (`bgNPC.Medics.calls`, kept 90 s). A free medic takes it, otherwise one is
spawned near the body, with an ambulance when Decent Vehicle is on and the config has `vehicles`. The ambulance
drives to the body like a police car on a chase, the medic gets out, kneels over the body for 6 s with voice
lines and medkit sounds (state `medic_revive`), the actor comes back (same type, model and skin; its ragdoll is
removed) and the medic returns to the car. A call closes when the body is gone (a client reports its ragdoll
faded or was cleaned up, or the server ragdoll was removed) or after 90 s; the medic then walks back to its car
and drives on with the siren off. The last 300 units to the body the medic walks straight, off the nav points.
Medics only take as enemies those who hurt them. Hook: `BGN_ActorRevived(actor, call)`.
