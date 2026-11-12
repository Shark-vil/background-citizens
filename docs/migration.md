# Comparison with 1.13 (Classic)

Audit date: **2026-11-12**. Compared: the Classic release **1.13.7** (tag `1.13.7`, SLibrary required) and the current branch `dev` at `da58946d` (version 2.4.0 in the working tree, publication on Workshop not verified). The comparison is static: source read side by side, whitespace ignored. It was not checked in game. Match percentages below count unchanged lines, not identical behavior.

| | 1.13.7 | Current |
|---|---|---|
| Lua files in `background_npcs_core` | 212 | 298 |
| Lua lines (with compiled routes) | ~20,500 | ~36,000 |
| Dependency | SLibrary | none |
| Files in `sound`/`materials`/`models`/`resource` | 47 | 981 |

**Summary.** The external contract (configuration, cvars, hooks, commands, saved data) is nearly unchanged. The internals were rewritten. With default settings the body is still an HL2 NPC (`bgn_actor_body npc`) and the brain is the FSM (`bgn_brain fsm`), but behavior in game differs because of new systems and changed spawn, navigation and wanted rules.

## Unchanged

- **Configuration:** `config/sh_main.lua`, `sh_config.lua`, `sh_player.lua`, `custom_modules/*` examples, DarkRP money and door modules are identical except for whitespace.
- **Extension points:** `custom_modules/config|preload|postload`, `bgNPC.cfg.*`, `bgNPC.cfg:SetActor`/`SetActorData`, legacy config adapter (`config/sh_oldconfig.lua`).
- **Hooks:** all 54 `BGN_*` hooks fired by 1.13 are still fired with the same arguments (only local variable names differ). Exception in meaning: see `BGN_WantedLevelDown` below.
- **Actor methods:** all 116 old methods exist; `StopStaticSequence` is an alias of `ResetSequence`.
- **Global API:** all 85 `bgNPC:*` methods exist, directly or through [compatibility aliases](reference/shared.md) in `api/compat/sh_legacy.lua`.
- **Commands:** all old console commands remain except `bgn_cl_draw_chunks_reload` (chunk system removed) and `cmd_bgn_spawnmenu_default_spawner` (already commented out in 1.13).
- **Data:** `background_npcs/nodes/*.dat|json`, `citizens_points/`, `seats/`, `spawn_area/`, `custom.dat`. Old route files are converted to the new graph on load and kept; see [navigation](systems/navigation.md). Bundled map compile files still write the 1.2 route format.
- **Tools and integrations:** all old Tools, DV entities and ULX modules.

## Partly changed (same logic, rewritten code)

| Area | Unchanged lines |
|---|---|
| FSM states `walk`, `idle`, `fear`, `retreat`, `run_from_danger`, `steal`, `killer`, `impingement`, `dyspnea`, chair seating, `zombie` | 57–92% |
| `defense` / `arrest` states | 68% / 66% |
| Spawner core / actor spawner / spawn zones / DV spawner | 58% / 49% / 77% / 82% |
| Wanted class / wanted actions (network message names kept, SNet replaced) | 57% / 66% |
| Relationships / team parent / damage and shot reactions | 54% / 77% / 35–59% |
| Spawnmenu, ambient sound | 76–85%, 77% |

Most of the difference is the replacement of SLibrary calls by `bgNPC.*`. Actor configs changed in content only in: citizens `getting_weapon_chance` 30 → 10 and `carry_items`; gang `respawn_delay = 30`; `dialogue` weights.

## Strongly changed

- **Core:** `classes/`, `global/`, `actions/` replaced by a single actor update loop with LOD, body adapters (HL2 NPC / NextBot) and brains (FSM / GOAP); see [architecture](architecture.md) and [brains](systems/brains.md).
- **Navigation:** own nodes and the runtime "dynamic mesh" replaced by providers (`bgn_nav_provider auto`: saved route → navmesh → nodegraph → own generator). Removed cvars: `bgn_dynamic_nodes_type`, `bgn_dynamic_nodes_alternative`, `bgn_enable_dynamic_nodes_only_when_mesh_not_exists`, `bgn_chunk_*`.
- **Dialogues:** `bgNPC.cfg.dialogues` (HL2 `vo/*` lines) replaced by `bgNPC.cfg.conversations` with own voices; see [conversations](systems/conversations.md).
- **Tactical groups:** new implementation (column/wedge/line formations, leader, wounded in the rear), **enabled by default**. `bgNPC:GetTacticalGroupGetFirstEnemy` / `GetTacticalGroupGetNearEnemy` were removed without an alias.
- **Gangs:** `gangster` is disabled; two gangs at 5% each with rival wars (`bgn_gang_war_chance 0.5`) and pack walking; see [gangs](systems/gangs.md).
- **New systems:** [medics and bodies](systems/medics.md) (up to 4), [scenic scenes](systems/scenic.md) (`bgn_scenic 1`, up to 4), carried items (5% of citizens), door hold/breach and temporary ragdoll, car break-in on arrest, offenders, actor fight cooldown, [ghost crowd](systems/ghost-crowd.md) (off), weapon pickup (off).
- **UI:** `tool_options/*` panels replaced by the [settings window](systems/menu.md); old panels partly available through `bgn_classic`.

### Changed defaults

| Cvar | 1.13.7 | Current |
|---|---|---|
| `bgn_spawn_radius_visibility` | 2500 | 2000 |
| `bgn_module_replics_language` | `english` | `auto` |
| `bgn_module_tactical_groups` | 0 | 1 |

About 50 cvars were added. Removed cvars (`bgn_chunk_*`, dynamic node options above, `bgn_optimize_no_think_*`) no longer have any effect.

## Changes that can break 1.13 behavior

1. **Recycling.** 1.13 moved an actor only beyond `bgn_spawn_radius`, or beyond the visibility radius when unseen. Now **any** actor unseen by players for `bgn_actor_unseen_time` (30 s) can be moved, even close behind a wall (`spawner/sv_actor_remover.lua`).
2. **Maps without routes but with a navmesh.** Runtime point generation is replaced by navmesh areas as points; HL2 NPCs walk to them with `SCHED_FORCED_GO`. Spawn and route distribution differ; on a map with a navmesh but no `.ain` nodegraph HL2 NPCs may walk poorly to far areas.
3. **State update rate.** The old state machine called `update` almost every frame. Now the brain runs every 0.2 s near players and 1 s far away; distant unarmed actors alternate 2 s pause / 1 s active (1.13 froze them completely beyond 500 units). Third-party states registered with `SetStateAction` that rely on frequent `update` react more slowly.
4. **`defense` in classic mode:** a civilian leaves the fight to the police (`fear`); a wanted actor retreats when the enemy is farther than 300 units; fighters may seize cars; with tactical groups the squad drives movement; self-healing no longer arms actors that have `getting_weapon_chance`.
5. **Wanted:** a wanted NPC (not a player) is dropped after 15 s outside every player's view; its level rises every 60 s; medics and arrested targets cannot become wanted; `LevelDown()` at level 1 now removes the wanted status (1.13: no-op); the second argument of `BGN_WantedLevelDown` is now the level instead of the kill counter. The addon itself does not call `LevelDown`, only external addons are affected. See [wanted](systems/wanted.md).
6. **Custom dialogues** in `bgNPC.cfg.dialogues` are silently ignored.
7. **Phrase language.** 1.13 preferred the game language over the cvar; now the server `bgn_module_replics_language` overrides everything, so a server with a saved `english` value forces English on Russian players. The server picks phrase indexes from the English table, so a custom language file must have the same number of phrases. See [voices](systems/voices.md).
8. **Population:** two gangs and wars instead of `gangster`, plus medics, scenes and squads, change both the mix and the frequency of fights. Disabling `gangster` by type name now leaves the gangs active.
9. **Synthetic `OnNPCKilled`:** `actor/components/sh_vehicle.lua` runs `OnNPCKilled` for an actor killed in a car; third-party kill or money counters can see an unexpected or extra event.

Internal `hook.Add` / net identifiers (about 60, e.g. `BGN_ThinkProcess`) disappeared; they are not a public contract.

## Limits of this audit

Not checked: behavior in game; semantic equivalence of each compatibility alias beyond its name; DV and DarkRP modules beyond file level. Highest risks: item 1 (recycling) and item 2 (navigation source).
