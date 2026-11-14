# Background NPCs combat audit fixes

All six findings in the [original audit](AUDIT_2026-11-13.md) have been addressed in the current core. Code and regressions are in `a5b2a903`; the original audit was preserved separately in `7fe48e1d`. The version remains `2.5.1`; nothing was published.

Русский: [согласованный отчёт](FIX_REPORT_2026-11-13.ru.md).

## Changes and effects

| Audit item | Fix | Result |
|---|---|---|
| 1. NPC memory extends itself | `EnemiesRecalculate` uses the actor's `enemy_last_seen`, without taking the maximum with engine memory. | NPCs still receive the remembered movement destination, but those steering writes no longer count as new sightings. An ordinary hidden enemy expires after more than 60 seconds. Actual sightings and newer shared observations retain their effect; wanted/always-visible exceptions remain. |
| 2. Negotiation/siege capability conflict | `Siege.CanStart` and `Join` reject `actor.hold_fire`. | An officer holding negotiation fire cannot initiate or follow a siege. The existing reverse guard already excludes siege participants from negotiation. The systems cannot restore each other's shooting capabilities. |
| 3. Manhack damage hook ordering | Existing `Combat.ResolveVehicleAttacker` resolves valid `bgn_siege_owner` from the attacker, then the optional inflictor. Reaction, arrest, seated damage, DV, harm/death accounting, negotiation and weapon-learning entry points use the common path. | Team/protection checks receive the owner before deciding, regardless of whether the separate native hook has already rewritten DamageInfo. A friendly manhack does not become an enemy because of callback order. The native attribution hook remains for engine damage credit. |
| 4. Lost memory after body replacement | `Actors.Rebind` transfers `enemy_last_position`, `combat_enemy` and `last_attacker`, and supplies the old position to the body's new enemy. It removes the old position key without changing observation age. | Enemy boarding/exiting no longer stops hidden-target pursuit or resets priority to another nearest enemy. Actor/UID remain stable; no deep copies are introduced. |
| 5. Equipment follows another enemy | Metrocop `Combat.EquipActor` uses `GetEnemy()` instead of `GetNearEnemy()`. | Stunstick/firearm selection follows the combat target. The arrest-target fallback remains when there is no combat enemy. Other tasks' geometric nearest-enemy queries are unchanged. |
| 6. NextBot combat teleports | `PullOut` and the teleport path in `HandleStuck` check existing `Combat.IsInCombatRadius`. | Both teleports are blocked while any living known enemy is within 1000 units inclusive. Outside that boundary, existing free/hidden-position rules apply. Siege protection stays independent; movement and optional jump attempts remain available. |

Fix 1 intentionally retains engine-memory updates needed to steer NPC pursuit. It is sufficient to stop treating those writes as evidence that extends the search. No new memory or capability-management system was introduced.

`Combat.ResolveVehicleAttacker(attacker, inflictor)` remains a SERVER API with an optional second argument; existing one-argument calls work. Payload ownership is resolved before the existing vehicle-driver rules. Invalid owners are not substituted. DATA formats, configuration and network messages are unchanged.

## Regression checks

The added logic is tested in existing `lua/background_npcs_core/tests/`, without production self-tests:

- `sv_pursuit.lua`: real NPC adapter with modelled `UpdateEnemyMemory`; search expiry and renewed observation; real Rebind in both realm branches preserving UID/position/age/priority and continuing pursuit; equipment and arrest fallback; both real NextBot teleport functions at 1000/1000.1 and independent siege protection.
- `sv_conflicts.lua`: both owner/reaction callback orders; ownership on the attacker or inflictor only; team protection, consistent attacker and rejection of removed owners.
- `sv_siege.lua`: negotiation hold rejects both operator and follower; ordinary participants still fill five near slots and withdraw to rear positions.
- `sv_negotiation.lua`: actual capability bit removal/restoration in the stub while retaining door capabilities.
- Existing DamageInfo stubs in `tools/test_police_force.py` only gained `GetInflictor`, now read by the exercised code.

Before the fixes, six affected checks detected the earlier defects. Afterward, an external LuaJIT/lupa run passed **36 tests, 0 failures**: 34 conflict/weapon/negotiation/pursuit/siege tests plus 2 Class/A*/GOAP tests. These use isolated environments, not native server `bgn_selftest` execution.

## Documentation and behavior tree

Updated aligned EN/RU pages:

- [Brains and combat](docs/systems/brains.md): authoritative memory age, target transfer, equipment, teleport guards and negotiation/siege exclusion.
- [Current tree](docs/systems/wanted.md#combat-continuation): owner before team checks; target selection/memory; negotiation/siege; combat protection for both unstuck paths. Calls are described against selected `GetEnemy`, not the nearest enemy.
- [Server API](docs/reference/server.md): the common resolver's optional inflictor.
- [EnemiesRecalculate](docs/classes/actor/functions/EnemiesRecalculate.md): selected target and memory lifetime; added the existing page's Russian translation.
- [Architecture](docs/architecture.md), [history](docs/history.md), [testing](docs/systems/testing.md#combat-audit-regressions): decision order/authority, local change boundary, regressions and evidence limits.

Removed contradictory siege descriptions: radio lines remain enabled; deployment can begin once doors start opening and the path is clear, rather than requiring fully opened doors. Added a stable Russian `hostage-negotiation` anchor so the history link resolves in both languages. `site/` was not changed.

Compact current sequence:

```text
Damage → common owner/driver resolver → team/protection/reaction
       → confirmed health loss → initiator → existing arrest → witnesses

Enemy → sighting/report with original timestamp → GetEnemy
      → equipment for that target → visible: fight; hidden: remembered position
      → body replacement: transfer position/time/references, retain UID
      → more than 60 s without fresh knowledge: forget ordinary hidden enemy

Negotiation hold_fire → cannot initiate/join siege
Siege participant → negotiation cannot acquire its weapon control
Combat + living known enemy ≤1000 → block both unstuck teleports
```

## Verification results

| Check | Result |
|---|---|
| Targeted Lua tests and GOAP | 36 passed, 0 failed. |
| `python tools/test_police_force.py` | Pass. |
| `python tools/test_actor_lod.py` | Pass. |
| `python tools/test_animator.py` | SERVER/CLIENT pass. |
| `python tools/test_carry_items.py` | Pass. |
| `python -m mkdocs build --strict --site-dir <temporary-output>` | EN/RU: exit 0, 0 warnings/errors. Output outside `site/`. |
| `git diff --check` | Pass. |
| `python tools/test_regressions.py` | As before the fixes, stops in spawn checks because watcher lacks `GetVehicle`. Subsequent checks were not verified by this run. |
| `python tools/test_actor_debug.py` | As before the fixes, main checks pass before the language-sync assertion fails. The complete script does not pass. |

The broad scripts are not reported as passing. Their existing failures were retained and disclosed, without changing unrelated production code to bypass them. The external harness reused `realm`, adapting Vector/CompileFile and GLua continue for LuaJIT. Regressions themselves are saved in SERVER tests and available through `bgn_selftest`.

## Work intentionally excluded

The hostage rule based on radius/fear/relative distance remains: it still does not check LOS or firing-line obstruction. The original audit treated this as a gameplay-design question, not one of the six defects. The limitation is now explicit in documentation.

Legacy was not changed. No new settings, dependencies or architecture were added. No in-game fixtures ran. Commits are local; nothing was pushed or deployed.

**Not checked:** native GMod, multiplayer, door/payload/vehicle physics, actual engine-memory timing and script reload during sieges/negotiation. **Risk:** isolated regressions establish these fixes, while arbitrary third-party hook compatibility and physical behavior still require in-game verification.
