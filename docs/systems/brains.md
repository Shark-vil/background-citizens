# Actor brains

An actor is split into an **actor** (data and rules), a **body** (`actor.body`: everything that talks to the
engine entity: movement, schedules, relationships, weapons, animation) and a **brain** (`actor.brain`: decisions).
Bodies and brains exist on the server only.

## Bodies

`bgn_actor_body auto|npc|nextbot` (default `auto`). On maps with a NavMesh, actors of the HL2 classes
`npc_citizen`, `npc_metropolice` and `npc_combine_s` spawn as `bgn_nextbot` (NextBot, `NextBotBody`), otherwise
as HL2 NPCs (`NPCBody`). The NextBot walks with the NavMesh path follower, opens doors, gets unstuck, and
shoots or hits with a real HL2 weapon held in its hand (players can't pick it up). HL2 NPCs that the bot
hates are told to hate it back.

## Choosing a brain

`bgn_brain auto|fsm|goap` (default `auto`). In `auto` an actor gets the brain from its config field
`brain = 'fsm' | 'goap'`, otherwise GOAP when the config has `weapons`, otherwise FSM.

## FSM brain

Runs the `update` callback of the current state (`bgNPC.States`), and picks a random state from `at_random`
when the actor has none. Reactions to damage and threats are random picks from `at_damage` / `at_protect`.

## GOAP brain

Used while the actor has enemies; without enemies it behaves like the FSM brain.

- **Facts** are measured by sensors once per second (and right after damage or a new enemy):
  `has_enemy`, `armed`, `is_police`, `low_health`, `enemy_close`, `enemy_armed`, `enemy_arrestable`, `police_called`.
- **Actions** run existing states: `attack` → `defense`, `arrest` → `arrest`, `flee` → `fear`,
  `call_police` → `calling_police`. An actor can only use actions whose state appears in its
  `at_damage` / `at_protect` config with a weight above zero.
- **Goals** (`eliminate`, `survive`, `report`) get a priority from the actor's **set**: `police`, `gangster`
  or `citizen` (by team, or the config field `goap_set`).
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

## LOD

Actors far from players update less often (`bgn_lod_near_radius`); idle unarmed actors out of range sleep
(`bgn_disable_logic_radius`). Hook: `BGN_ActorLODChanged(actor, lod)` (1 near, 2 far, 3 dormant).
