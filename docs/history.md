# Version history and documentation baseline

Reviewed against Git through tag **2.3.0** (`2258b49`) and current **2.3.1 dev** (`7459c3c7`, 2026-11-10). `version.txt` and `bgNPC.VERSION` both say 2.3.1. There are 48 commits between the tag and this baseline. A version string does not prove publication on Workshop.

## Through 2.3.0

| Period | User-visible development and current documentation |
|---|---|
| 1.x | Original NPC/state system, route editor/compilation, configurable populations/teams, wanted/arrest, voices and optional addon integrations. Legacy routes and API compatibility remain relevant; old SLibrary/SNet examples are no longer the modern API. |
| 2.0.0–2.0.1 | Core rewrite with internal classes/network/scheduler, optional NextBot bodies and GOAP, navigation providers, settings UI, ghost crowd; fixes to ghost identity/entity lifetime. No required SLibrary. See [architecture](architecture.md), [brains](systems/brains.md), [ghost crowd](systems/ghost-crowd.md). |
| 2.1.0–2.1.2 | Behavior/settings expansion; first-start windows restricted to the single-player/listen-server owner; classic NPC body/FSM defaults restored and animation-death handling fixed. See [quick start](getting-started.md). |
| 2.2.0 | Classic spawnmenu pages and admin `bgn_classic`/chat aliases; corpse cleanup disabled by default so external cleanup can work. |
| 2.2.1–2.2.2 | Legacy route/duplication recovery and conversion; save/load ordering, preservation of existing and large graphs, cycle-safe actor saves, Workshop route export; arrested actors retain their pose. See [navigation](systems/navigation.md). |
| 2.3.0 | Offenders and visible teammate enemy sharing; NextBot unarmed animations/jump option/exit placement, movement/gesture/animation fixes; medics avoid a killed colleague's area; wanted after refusing arrest; police keep firearms through combat; dialogue voice/state sync and arrest ally protection. |

Historical fixes describe the reason for current contracts, not separate APIs to reintroduce. The current body and brain defaults are `npc` and `fsm`.

## After 2.3.0: current 2.3.1 branch

| Area | Current behavior / owning documentation |
|---|---|
| Spawn and debug | Visibility checks and validation are atomic; admin actor overlay; unseen actor recycling, independent car radius; occluded whole-car spawning and pursuit-car catch-up. [Navigation](systems/navigation.md), [testing](systems/testing.md). |
| Vehicles | Measured simfphys headings, pedestrian detours, bounded recovery/alternate lanes, cleanup; native DV trace timing retained; police driver/passenger return and service-car access. [Vehicles](systems/vehicles.md). |
| Character lifecycle | Stable actor/UID through DV entity replacement, safe health accessors, seat-specific exit hull checks and blocked-exit retention; seated damage goes through reaction/witness handling. [Actor API](classes/actor/index.md). |
| Policing | Arrest module load order corrected, surrender no longer restarts a fight, officers hold arrest unless attacked; vehicle suspects are shot with ranged weapons; an actor standing still in a car gets the car break-in and arrest like a player. [Arrest](systems/arrest.md). |
| Gangs | Black Raven/Red Wolf, light/heavy weapons/models, bounded initial rosters, rival wars, pack walking; direct victims still fight back outside roster caps. [Gangs](systems/gangs.md). |
| Combat pacing | Regional 60-second protection cooldown applies only between actors, not player/foreign NPC attacks, and never to the police; existing skirmish participation and self-defense remain. Officers in cars receive shared enemies. Gangsters respawn after 30 seconds. [Gangs](systems/gangs.md). |
| Medics and bodies | Hopeless verdicts, body inspection/cleanup and completed-call release; vehicle collisions can be saved with normal chances; ambulance/medic protections. [Medics and bodies](systems/medics.md). |
| NextBots / damage | Stuck recovery selects nearby free navigation space, avoids teleporting into vehicles; fixed custom-chair positioning. Actor hits on seated actors triple damage in 20% of rolls, double in 50%, remain unchanged in 30%. [Brains](systems/brains.md), [vehicles](systems/vehicles.md). |

## Reproduce the comparison

```text
git log --reverse --no-merges --oneline 2.3.0
git log --reverse --oneline 2.3.0..7459c3c7
git diff --stat 2.3.0 7459c3c7 -- lua docs
```

Read implementation and callers before changing a documented contract. Commit subjects alone do not prove behavior. [Maintenance rules](ai.md).
