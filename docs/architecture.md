# Project architecture

Documentation baseline: **2.3.1**, branch `dev` at `7459c3c7` (2026-11-10). Tag `2.3.0` is `2258b49`; subsequent behavior is explicitly recorded in [version history](history.md). This describes the repository, not a promise that Workshop already contains these commits.

## Runtime boundaries

| Realm | Owns | Entry points |
|---|---|---|
| Server | Population, bodies/brains, AI, navigation, damage, wanted/arrest, medics, vehicle providers | `sv_` files and server branches in `sh_` |
| Client | Menu, voices/subtitles, ghost visuals, wanted HUD, route/debug rendering | `cl_` files and client branches in `sh_` |
| Shared | Classes, configuration, API definitions, serialization and received actor records | `sh_` files; data is independent in each Lua realm |

A shared filename says where a file loads. It does not guarantee a method can drive gameplay on the client. Use the [realm references](reference/shared.md).

## Load sequence

`lua/autorun/background_npcs.lua` sends and includes `background_npcs_core/sh_init.lua`. The loader sorts files, loads `sh_`, `sv_`, then `cl_` within each directory, recursively; explicit includes are deduplicated. Replic language files and menu option translations are loaded manually.

1. Core: notices, classes, networking, utilities, scheduler, then remaining helpers.
2. Built-in config/actors/phrases/states, custom `config`, legacy config adapter.
3. Public API, cvars, commands, custom `preload`; save config defaults.
4. Actor class/components/body adapters, events/update/sync.
5. Navigation base/providers/IO, then the DV provider.
6. Team and wanted modules, arrest module, remaining systems; brains, spawners, integrations.
7. Menu languages/UI/debug; custom `postload`; `BGN_PostLoadScripts`.

Order matters: offender/state modules capture the registered arrest module. Reloading via `bgn_scripts_reload` reruns this loader; a map reload is the clean validation for changed bodies and persisted world state.

## Files and responsibilities

All paths below are relative to the repository root. Under `lua/background_npcs_core/`:

| Path | Responsibility / connections |
|---|---|
| `sh_init.lua` | Version, shared storage, deterministic loading. |
| `core/` | Class factory, task budget, network codec/chunks, cvar/command infrastructure, self-tests, notices, utility helpers. |
| `config/` | Main settings; `actors/` defaults and inheritance; `states/` dialogue/scenic/arrest data; `replics/language/` text and voice definitions. |
| `custom_modules/config`, `preload`, `postload` | Extension stages, also discoverable from separate addons through merged GMod Lua paths. |
| `api/` | Actors/config/points/states/modes/vision/statistics/assertions and combat facade. `compat/sh_legacy.lua` retains old colon APIs. |
| `cvars/`, `commands/` | Setting registration, defaults and administrative actions. |
| `actor/sh_actor.lua`, `components/` | Character identity/health/lifetime and partial state, enemy, target, team, movement, weapon, animation, speech and vehicle methods. |
| `actor/body/` | Server NPC/NextBot engine adapters. |
| `actor/update`, `events`, `sync` | Scheduled simulation, damage/death/save hooks, server snapshots and client binding. |
| `nav/` | Provider facade, graph/A*, custom/navmesh/nodegraph providers; `generator/` incremental route building, `io/` editor/save/compile/dupes, `legacy/` conversion. |
| `brain/fsm/`, `brain/goap/` | State execution and combat planning. States call Actor methods; bodies perform engine actions. |
| `spawner/` | Visibility-safe population placement/recycling, separate vehicle ranges, pursuit reinforcement and cleanup. |
| `systems/` | Wanted/arrest, offenders, medics/corpses, teams/enemy sharing, gang wars/support/packs and combat cooldown, dialogue, seats, scenic, ghost crowd, modes. |
| `modules/` | Optional integrations: DV, DarkRP, StormFox and NPC mods. `dv/` owns provider access, traffic recovery, pedestrian detours, return and vehicle damage. |
| `ui/` | Settings window, Classic panels, wizard/welcome, spawnmenu, update display, translations. |
| `debug/` | Admin actor overlay, diagnostic report/camera, movement visualization and automated in-game checks. |

Other repository paths:

| Path | Contents |
|---|---|
| `lua/entities/` | NextBot actor and DV-related scripted entities/controllers; inspect each entity's init/shared/client files for realm. |
| `lua/weapons/` | Tools, including route editing support. |
| `lua/autorun/` | Addon bootstrap. |
| `lua/ulx/` | Optional ULX administrative integration. |
| `materials/`, `models/`, `sound/`, `resource/` | Runtime visuals, gang models/skins, voice assets and UI localization. |
| `tools/` | Python regression checks, opt-in DV lab fixtures/bridge client, asset/voice generation helpers; not loaded automatically by the game. |
| `docs/`, `mkdocs.yml`, `requirements-docs.txt` | EN/RU site sources, navigation/translations, pinned documentation dependencies. |
| `.github/` | CI/site deployment configuration. |
| `addon.json`, `version.txt`, `LICENSE`, `README.md` | Addon metadata, release number, license and entry page. |
| `site/` | Ignored generated documentation; never edit by hand. |
| `quarantine/` | Retained files outside the active loader; not an extension entry point. |

Local planning/lab notes are not release contracts. Do not copy machine-specific paths or temporary bridge setup into runtime installation instructions.

Spawning loads resources through normal gameplay creation. There is no first-player-spawn NPC/vehicle warm-up pass. NextBot relationship sampling uses player dispositions without creating probe entities; see [brains](systems/brains.md).

## Main relationships

```text
config -> resolved Config cache -> per-actor config copy
navigation + player visibility -> spawner -> Actor registry
Actor -> brain (FSM / GOAP) -> state callbacks -> Actor methods -> body -> engine entity
systems/events -> reactions / wanted / arrest / medic calls -> state transitions
Actor <-> vehicle provider -> DV controller + chassis + seated visual
server Actor -> PVS snapshots + generation -> client registry -> UI / sound / rendering
```

The actor and UID survive vehicle boarding; its entity and body adapter do not. Registries, enemy/target references, wanted state and statistics follow the replacement. Addons must follow `BGN_ActorEntityChanged(actor, old, new)` for their own entity-local data.

Door shelter is server-owned (`systems/sv_door_hold.lua`, `brain/fsm/states/sv_hold_door.lua`); GOAP chooses
the action. Temporary `knocked_down` keeps the original entity and body adapter, hides/freezes them and uses
a server ragdoll for physics and forwarded damage. The actor update loop runs only recovery while down;
standing requires a free hull. Client synchronization/render optimization preserves the server's hidden-body flag.

`systems/sh_carry_items.lua` shares item definitions, model/animation checks and chance selection. SERVER owns
real actors' item lifetime; body adapters exclude carried props from combat weapon
queries. Only NextBot activity tables supply carrying locomotion. HL2 NPC movement is unchanged; CLIENT
attaches briefcases to the hand bone on both body types; they never spawn physical drops. `systems/cl_carry_items.lua` manages real actors' client props from
`carry_visual` in existing PVS snapshots. The newspaper hides the NextBot's driving parcel and fits the stock
paper model between both hand bones. CLIENT also owns ghost visuals. Ghosts and actors materialized from them never carry items.
Scenic placement remains SERVER-owned, including room/ledge traces, furniture bounds and atomic couch pairs.

`debug/sv_scenic.lua` owns admin scene placement, test ownership/Undo and the one-cycle GOAP door test.
`lua/weapons/gmod_tool/stools/bgn_scenic_debug.lua` supplies the selector and live inspection HUD through the
existing server-to-client Tool RPC. Manual placement validates the admin owner in both creation and delayed
setup; only that path bypasses hidden-position checks. Normal spawner model hooks still decide all actor models.

## Configuration and stored data

Cvar defaults are defined in `cvars/sh_cvars.lua`, `sv_cvars.lua`, `cl_cvars.lua`; registration and permissions are in `core/sh_cvars.lua`. Server settings are admin-controlled; client voice/UI options stay local. Actor definitions resolve `inherit` and `@type` references, cache the result and copy it on creation. After editing definitions, clear the config cache; existing actors retain their copy.

GMod DATA paths are relative to `garrysmod/data/`, not this addon: `background_npcs/nodes`, `graph`, `seats`, `compile` (created by bootstrap), diagnostic `background_npcs/test_report.txt`. DV waypoints are separate from pedestrian routes. Preserve users' route files; legacy import/duplication conversion must not overwrite unrelated points. Compiled routes are Lua distribution artifacts generated from stored data.

## Development and verification

- [Build and contribute](contributing.md): bilingual pages and strict site build.
- [Testing](systems/testing.md): diagnostics, Python/Lua regressions and opt-in vehicle fixtures.
- [AI documentation rules](ai.md): scope, sources, realm contracts and maintenance checklist.

Unit/stub checks do not establish real GMod physics, multiplayer permission behavior or every optional-addon combination. Record exact conditions for live evidence.
