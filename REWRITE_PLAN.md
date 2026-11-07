# Background NPCs — Core Rewrite Plan

Branch: `refactor/core-rewrite`. Language: GLua. Progress log: `CHANGELOG.md`.

## Goals

1. Performance: one budgeted scheduler instead of several `async` loops; distance-based LOD for far actors.
2. Fix bugs found while porting each subsystem.
3. GOAP brain for combat/complex actors, FSM brain kept for simple ones (unarmed civilians). Brain type per actor config + global cvar override.
4. Clean public API and documented hooks in the places that matter. Old hooks still fire, marked **OUTDATED**.
5. Keep all UI (tools, spawn menu, settings panels) and the abstract `ACTOR` that wraps any NPC or NextBot.
6. NextBot actors (HL2 models first) on maps with NavMesh; HL2 NPCs elsewhere or when forced.
7. Faster, more flexible custom node generator for maps without NavMesh and without nodegraph.

No dependency on slib (the slib addon itself stays untouched).

## Navigation tiers

| Map has | Actor body | Movement | Spawn / walk points |
|---|---|---|---|
| NavMesh | NextBot (`bgn_actor_body auto`) | `PathFollower` on NavMesh | Random points on nav areas |
| Nodegraph (`maps/graphs/<map>.ain`) | HL2 NPC | Engine navigation (`SCHED_FORCED_GO`) | Parsed `.ain` node positions |
| Neither | HL2 NPC | Own node graph, node-by-node | Own nodes (generator / point editor) |

- `bgn_actor_body auto|npc|nextbot` forces a body type (nextbot needs NavMesh).
- A manually saved route file for the map (point editor) overrides the automatic choice of points.
- Engine NavMesh generation is never triggered.

## Target layout

```
lua/autorun/bgn_init.lua            entry point (replaces slib_autoloader)
lua/background_npcs_core/
  core/        class system, scheduler, net, i18n, cvars, commands, hooks (+OUTDATED shims), utils
  api/         public namespaces
  actor/       Actor class + components (targets, enemies, team, animation, vehicle)
  actor/body/  Body interface, NPCBody, NextBotBody
  brain/       Brain base, fsm/, goap/ (world state, planner, actions, goals, sensors)
  behaviors/   executors shared by FSM states and GOAP actions (walk, flee, fight, sit, ...)
  nav/         NavProvider interface, navmesh / nodegraph / custom providers, node graph, generator, legacy converter
  spawner/     actor, zone and DV spawners/removers
  modules/     integrations (DarkRP, DV, StormFox, ULX, n2money, iNPC, ...)
  config/      actor configs and settings (format kept)
  ui/          client menus and tool panels (kept, ported to new API)
  custom_modules/  user scripts, loaded as before
lua/entities/bgn_nextbot/           NextBot actor entity
```

## Stages

Each stage ends with a working, loadable addon. ✅ = verify in game.

### Stage 0 — Preparation
- [ ] This plan, `CHANGELOG.md`.
- [ ] Lint setup (`glualint`) and an in-game self-test command `bgn_selftest` for pure logic (planner, graph, serializer).

### Stage 1 — Core layer, slib removal ✅
- [ ] `core/class`: minimal OOP (`Class(name, base)`, inheritance, `super` calls, `IsInstanceOf`).
- [ ] `core/scheduler`: coroutine tasks with a per-tick time budget (replaces `async.Add/AddDedic`).
- [ ] `core/net`: channels on `net`, compressed tables, request/response, rate limit + admin checks (replaces `snet`).
- [ ] `core/i18n`, `core/cvars` (incl. global replicated cvar callbacks), `core/commands`, `core/util` (`chance`, uuid, sound duration, view checks, first player spawn hook, timers).
- [ ] Replace the remaining slib bits: animator, fake player component, dupe handler, spawnmenu content type.
- [ ] New entry point in `autorun`, remove `slib_autoloader` and the slib error screen.
- [ ] Port all callers; no `slib.`/`snet.`/`async.`/`scommand.` references left.

### Stage 2 — Actor and NPC body ✅
- [ ] Split `sh_actor_base.lua` (1700 lines) into `Actor` + components.
- [ ] `Body` interface (move, stop, play sequence, weapon, health, eyes) and `NPCBody`.
- [ ] Single actor update loop on the scheduler with LOD (near: every tick slot, far: rarely, unseen: minimal).
- [ ] New hooks + OUTDATED shims for the old `BGN_*` hooks.
- [ ] Port spawners/removers, sync, vehicle (DV) logic.

### Stage 3 — Navigation ✅
- [ ] `NavProvider` interface + navmesh, nodegraph (`.ain` parser), custom providers; auto selection.
- [ ] New node graph: spatial hash grid, A* with binary heap, compact save format (new file name/version).
- [ ] New generator: flood fill from spawn points with hull traces, per-tick time budget, graph simplification, region/around-player generation, progress UI.
- [ ] `bgn_convert_legacy_nodes` — converts old `background_npcs/nodes/*.dat|json` to the new format.
- [ ] Port point editor, spawn area, seat tools.

### Stage 4 — Brains: FSM + GOAP ✅
- [ ] `Brain` base; `FSMBrain` with `State` class; port the 21 existing states onto shared behaviors.
- [ ] GOAP: bitmask world state, actions (preconditions/effects/cost/executor), goals (priority), A* planner with plan cache, event-driven replanning, sensors on low frequency.
- [ ] GOAP sets for police, gangsters, armed citizens; FSM stays default for unarmed civilians.
- [ ] Switch: actor config `brain = 'fsm'|'goap'`, cvar `bgn_brain auto|fsm|goap`.

### Stage 5 — NextBot body ✅
- [ ] `bgn_nextbot` entity: HL2 human models, activity-based animations, locomotion, doors, stuck handling.
- [ ] Weapons and combat for NextBot (HL2 weapons), damage/relationships with NPCs and players.
- [ ] `NextBotBody` adapter; body choice by navigation tier.

### Stage 6 — API, docs, cleanup ✅
- [ ] Final API surface and hook reference, OUTDATED list.
- [ ] Rewrite `docs/` (English), remove stale pages.
- [ ] Remove dead code and old files; full regression run in game.

## Risks
- NextBot combat has no engine AI: everything (aim, cover, reload) is ours — biggest stage.
- In-game behaviour is only checked at the ✅ stages.
- Third-party addons using undocumented internals may break; documented API and old hooks keep working.
