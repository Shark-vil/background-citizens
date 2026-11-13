# Citizen/police team hostility fix

Date: 2026-11-13. Baseline: `dbc7d524`, local 2.5.1, dev branch.
Fix and test commit: `9f5dc1a3`.
Scope: current core, NPC/FSM and NextBot/GOAP, on-foot/seated damage, help, phone/radio reports, wanted, arrest and team changes. Legacy was excluded.

## Confirmed findings and changes

Real Lua modules reproduced the defects in an isolated engine model; the first six regressions failed before the fixes. The user's live scene was not recorded, so not every discovered bypass can be attributed to that specific incident.

1. **Friendly bullets explicitly caused fear.** The same-team branch in `actor/events/sv_self_damage.lua` took the shooter's nearest enemy and called `AddEnemy(danger, 'fear')` → `SetState('fear')` → `StayOutOfFight()` before checking `bgn_team_damage`. Even a blocked police bullet could frighten a calm civilian. That block was removed.
2. **AddEnemy rejection happened after state changes.** Help and wanted notifications could change state before discovering the target was an ally. Team checks now precede reactions; police broadcast/initialization reactions require an accepted enemy.
3. **Phone reports and AddWanted did not protect residents.** Calls did not recheck every enemy's current team, and the common wanted entry point protected medics but accepted citizens. Calls now exclude allies; AddWanted rejects residents/medics; periodic cleanup removes stale resident wanted entries. A valid unrelated enemy is still reported.
4. **Offender conversion bypassed immunity.** Ordinary civilian kills removed residents. The police-car handler also called `OffenderFromRamming(attacker)` for any damage, including bullets: the collision-type check gated only the random reaction. Ordinary-kill conversion was removed; conversion now requires a proven vehicle collision.
5. **Team changes left stale targets.** SetTeam/AddTeam remove mutual enemy entries and corresponding body targets. Becoming a resident clears wanted; sharing the primary officer's team removes that actor's arrest. SERVER HasEnemy rejects current teammates even with a stale entry; recalculation removes it. Removing a teammate restores `D_LI`.
6. **Other decisions consumed friendly damage.** It no longer reaches BGN_ConfirmedDamage/arrest escalation, records a recent direct attacker or marks a distant ranged threat. Arrest registration rejects teammates. With `bgn_team_damage 1`, friendly police hits cannot activate the seated-driver execution timer.

## Vehicle exceptions

`OffenderFromRamming(attacker, damage, police_target)` requires a living civilian driver, their actual car, positive `DMG_CRUSH`/`DMG_VEHICLE` and that car as attacker/inflictor. Medics and peaceful mode remain protected.

- Running over a civilian on foot converts the driver before normal team protection.
- Repeatedly ramming the same officer on foot or occupied police car requires at least 3 seconds. A gap over 3 seconds or a different target restarts the series. The previous 10% reaction chance remains per eligible impact after that minimum.
- Bullets, melee, ordinary kills and one accidental police bump do not remove residents.

The 3-second minimum/gap makes “prolonged ramming” concrete; previously there was no duration threshold. No cvar was added. Only the driver's own team copy changes to offenders; wanted, when enabled, follows team removal. Wanted expiry does not restore the team.

## Call trace and current tree

`EntityTakeDamage` → resolve owner/driver → vehicle exception → team protection → personal reaction → actual damage → `PostEntityTakeDamage` or `BGN_PostVehicleDamage` → `ConfirmDamage` → arrest/witness/wanted subscribers.

```text
Police hits a civilian sharing its team
├─ Ordinary bullet → keep residents
│  ├─ bgn_team_damage = 0 → block health damage
│  └─ bgn_team_damage = 1 → ordinary health damage only
│     └─ No fear, enemy, help against an ally, escalation or driver execution timer
├─ Help/report contains a stale ally → exclude before reaction/reporting
├─ AddWanted receives a resident → reject
└─ Proven civilian-driver vehicle impact
   ├─ Civilian on foot → remove residents
   ├─ Officer/police car → duration threshold + chance
   └─ Only after removing residents → normal conflict and eligible wanted
```

GMod hook ordering is unspecified. Checks now cover reactions, confirmed damage, reporting completion and the wanted entry point independently. BGN_ConfirmedDamage subscribers retain independent order; that notification is not emitted for friendly damage.

The [full behavior tree](docs/systems/wanted.md), EN/RU references, vehicle/arrest/brain/testing pages and history were updated.

## Verification and limits

- **48/48** selected LuaJIT/lupa tests: 12 new regressions in `lua/background_npcs_core/tests/sv_team_damage.lua` plus 36 existing conflict/weapon/negotiation/pursuit/siege/GOAP checks.
- New tests use real team/combat/policing modules with modelled NPC/NextBot entities, team damage off/on, valid outsider reporting, collision proof/duration/gaps/target changes, medic/peaceful protection, stale wanted, team changes and seated health damage.
- `tools/test_police_force.py`, `tools/test_actor_lod.py`, `tools/test_animator.py` and `tools/test_carry_items.py` passed. Startup load order and removal of the old kill-conversion hook passed separately.
- Touched Lua syntax passed external LuaJIT compilation; GLua continue was substituted only for syntax checking.
- Strict MkDocs build with a temporary site-dir: zero warnings/errors. git diff --check passed.
- Full `tools/test_regressions.py` and `tools/test_actor_debug.py` still encounter their earlier fixture failures: missing GetVehicle in a spawn stub and the final language-sync assertion. The changed startup section passed separately.
- Native bgn_selftest, engine damage/vehicle physics, multiplayer and third-party addon interactions were not verified. The standard server command `bgn_selftest` loads the new tests.

**Existing damaged sessions:** actors already incorrectly converted to offenders are not restored automatically. Old state records no conversion reason; blanket restoration would erase legitimate vehicle offenses. Reload the map or repair a specifically identified actor. Script reload removes the old kill hook but cannot restore a previously lost team.
