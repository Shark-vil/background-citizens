# Version history and documentation baseline

Local 2.5.1 dialogue fix (publication not verified): random state phrases and ambient coughs no longer interrupt conversation participants, including gathering and player-interruption phases. See [conversations](systems/conversations.md).

Local 2.5.1 follow-up fix (publication not verified): vehicle exits and lethal damage tolerate an already removed DV occupant entity; wanted detection skips living actors without a valid current entity. Stored character identity/health and normal exit obstruction checks are preserved. See [vehicles](systems/vehicles.md) and [regressions](systems/testing.md#core-engineering-audit-regressions).

Local 2.5.1 engineering audit (publication not verified): corrected disabled mechanics, recurring services,
scheduler mutation, reload identity/snapshot counters, empty/sparse navigation queries, GOAP planning,
appearance selection, regeneration and client receivers. Removed per-entity spawnmenu config IO;
player-owned spawns now use gamemode permission/counting hooks. Network uploads have explicit bounds.
Architecture and defaults remain; see the [audit and verification limits](core-audit.md).

Local 2.5.1 change (publication not verified): optional panic and threat search (`bgn_threat_search`, default off). An ally who sees a kill but not the killer (a trace from the victim, no view cone) panics (residents) or searches where the killer stood (police, gangs), walking within 1000 units of the killer; the spawner does not recycle them meanwhile. Anyone holding the killer's weapon class seen 3 checks in a row within 500 units in view becomes an enemy. See [brains](systems/brains.md#threat-search).

Local 2.5.1 team protection change (publication not verified): the vehicle offender exception (`bgNPC.OffenderFromRamming`, `systems/sv_offender.lua`) is removed. Running over a civilian or ramming police no longer moves a civilian driver from `residents` to `offenders`; police in a car ignore a civilian driver's ram. See [wanted](systems/wanted.md).

Local 2.5.1 SERVER optimization (publication not verified): the object scan behind `BGN_ActorVisibleAtObject`/`BGN_ActorLookAtObject` searches 100 units around an actor instead of 1000 (the built-in listeners react within 80 units), and its forward trace runs once per scan. The once-per-second foreign-hostility check rejects non-NPC entities first, and the static animation controller checks `IsAlive` only for animated actors. Behavior is unchanged.

Local 2.5.1 police-call fix (publication not verified): damage/protection reactions reject calls about already wanted or police-known enemies before enemy registration; entering a call also requires a valid selected enemy. Active-call completion rules are unchanged. See [police calls](systems/wanted.md#completing-a-police-call).

Local 2.5.1 recycling change (publication not verified): spawn delay is `0` and the teleport limit is `10` per second. Move instead of removing remains enabled (`1`). The fast-check setting is removed: SERVER always uses one scheduler yield before each actor's recycling check. Saved values of the remaining cvars are preserved. See [settings](systems/menu.md).

Local 2.5.1 citizen/police fix (publication not verified): friendly hits no longer start fear or confirmed conflict reactions; residents cannot be reported as wanted. Team changes reconcile targets/wanted/arrest. Only proven vehicle collisions can turn a civilian driver into an offender: running over a civilian or repeated police ramming, with a 3-second minimum and the existing 10% reaction chance. See [wanted rules and behavior tree](systems/wanted.md).

Local 2.5.1 audit fixes (publication not verified): NPC pursuit writes no longer extend the 60-second actor search; body replacement preserves position memory and target priority; police equipment follows the selected enemy. Negotiating officers cannot start/join sieges, payload ownership is resolved before damage reactions, and both NextBot unstuck teleport paths respect combat-radius protection. See the [updated decision tree](systems/wanted.md#combat-continuation) and [developer checks](systems/testing.md#combat-audit-regressions).

Local 2.5.1 change (publication not verified): stable combat target priority, pursuit of last observed hidden positions, shared sighting memory, visible-only cover and combat recycling/unstuck protection (fixed 1000-unit radius). See [brains](systems/brains.md).

Local 2.5.1 change (publication not verified): police radio lines for sieges (position, breach, grenade, manhack,
outcome), a downed or lost target and hostage negotiation; sieges no longer mute actor voices; a wanted target is a
known position even out of sight. See [brains](systems/brains.md#hostage-negotiation).

Local 2.5.1 change (publication not verified): GOAP single-exit room sieges with shared front/rear group
positions, animation-gated metropolice manhacks/combine grenades and probabilistic door breaching/opening.
The NavMesh-backed tactic and its limits are described in [brains](systems/brains.md#sieging-a-single-exit-room).

Local 2.5.1 change (publication not verified): optional held-lethal-weapon reaction for residents/police,
default off, one-second LOS/FOV checks within 800 units. Weapon learning continues while off, excludes
explosion/vehicle kills and persists new classes in a server cache/DATA file. See [brains](systems/brains.md#lethal-weapons)
and the [behavior tree](systems/wanted.md#behavior-decision-tree).

Reviewed against Git through tag **2.3.0** (`2258b49`) and current **2.3.1 dev** (`7459c3c7`, 2026-11-10). `version.txt` and `bgNPC.VERSION` both say 2.3.1. There are 48 commits between the tag and this baseline. A version string does not prove publication on Workshop.

Local Animator fixes after the baseline: `dance` starts after state cleanup, active donor animations synchronize to ready players entering PVS, stopping releases Animator-owned NPC freeze, and client copies preserve appearance at startup. See [donor animations](systems/brains.md#donor-animations). Publication is not verified.

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
| Spawn and debug | Visibility checks and validation are atomic; admin actor overlay; unseen actor recycling, independent car radius; occluded whole-car spawning and pursuit-car catch-up; cover must block the sight line at least 40 units short of the spawn point, and the player's own car is not cover. [Navigation](systems/navigation.md), [testing](systems/testing.md). |
| Vehicles | Measured simfphys headings, pedestrian detours, bounded recovery/alternate lanes, cleanup; native DV trace timing retained; police driver/passenger return and service-car access. [Vehicles](systems/vehicles.md). |
| Character lifecycle | Stable actor/UID through DV entity replacement, safe health accessors, seat-specific exit hull checks and blocked-exit retention; seated damage goes through reaction/witness handling. [Actor API](classes/actor/index.md). |
| Policing | Arrest module load order corrected, surrender no longer restarts a fight, officers hold arrest unless attacked; vehicle suspects are shot with ranged weapons; an actor standing still in a car gets the car break-in and arrest like a player (officers at the doors no longer block pulling it out); shots at any car base reach the occupants in full, and the police kill a driver after `bgn_police_car_kill_time` seconds; an unarmed actor out of a fight hit by the police gives up with 30%. [Arrest](systems/arrest.md). |
| Gangs | Black Raven/Red Wolf, light/heavy weapons/models, bounded initial rosters, rival wars, pack walking; direct victims still fight back outside roster caps. [Gangs](systems/gangs.md). |
| Combat pacing | Regional 60-second protection cooldown applies only between actors, not player/foreign NPC attacks, and never to the police; existing skirmish participation and self-defense remain. Officers in cars receive shared enemies and spot hostile NPCs/NextBots near the car, so they step out. Gangsters respawn after 30 seconds. [Gangs](systems/gangs.md). |
| Medics and bodies | Hopeless verdicts, body inspection/cleanup and completed-call release; vehicle collisions can be saved with normal chances; ambulance/medic protections. [Medics and bodies](systems/medics.md). |
| NextBots / damage | Stuck recovery selects nearby free navigation space, avoids teleporting into vehicles; fixed custom-chair positioning. [Brains](systems/brains.md), [vehicles](systems/vehicles.md). |
| GOAP | Finished actions (cover, backup) advance the plan instead of being blocked; no endless cover loop; an officer holding an arrest makes the plan wait; picking a reaction never starts a surrender. GOAP plans only a fight the FSM started (`defense`/`retreat`); reactions are the config roll again, an enemy alone no longer starts a fight. An outnumbered officer takes cover, then calls backup, which makes its enemies wanted; one armed enemy no longer triggers backup. [Brains](systems/brains.md#goap-brain). |
| Wanted | As in 1.x, the timer stays full while residents see the target, an actor too (not only while it fights); a target in a car is seen through its car body. A wanted NPC gains a level every `bgn_wanted_level_up_period` seconds. A wanted NPC is dropped after 15 s outside every player's field of view or farther than half of `bgn_spawn_radius_visibility` (obstacles ignored); the vehicle spawn exclusion moved to `bgn_vehicle_spawn_visibility_radius`. [Wanted](systems/wanted.md), [menu](systems/menu.md). |
| Lifecycle cleanup | Actor bodies without a live registered actor are removed after 3 s regardless of health (frozen bodies killed while dormant), also with `bgn_enable 0`. [Brains](systems/brains.md#gangs). |

Working-tree fix after this baseline (version string 2.4.0, publication not verified): door scenes use fully
closed doors, knocking faces the panel, and opening/removing the linked door returns participants to normal AI.
The admin spawn command also uses the door finder. See [scenic scenes](systems/scenic.md).
Five context-dependent scenes (both couches, radio operator, sky watch and door brace) were initially made manual-only;
all scenic actors keep ordinary spawn/model-hook selection rather than overriding their models.
GOAP actors in a hopeless fight can close and hold an open rotating door; police can kick it open, throwing
the holder into a temporary ragdoll without extra damage. Recovery preserves the original actor/entity and
health, requires free standing space, and restores its previous fight/flee behavior. See [brains](systems/brains.md).
The admin Scene debugger Tool adds visible manual placement, model/state/animation inspection, owned cleanup/Undo
and a one-cycle GOAP door check. The console scene spawner shares its placement/Undo path. Chair reservations
are released when scenic bodies are removed; previous seating states finish before scene placement.
See [scenic debugging](systems/scenic.md#scene-debugger-tool).
Scene debugger errors distinguish a missed door from an open/moving door or blocked floor space. Owned test
actors are excluded from automatic population recycling/removal and scenic lifetime/distance cleanup.
The scenic overhaul returns couches/radio to automatic indoor-only placement, removes cowering, splits wall
fatigue from floor poses, adds ledge seating and solitary pose variants, and makes couch pairs atomic.
Per-scene switches and per-actor `carry_items` settings control future spawning. Citizens have a combined 5%
carried-item chance. A follow-up confines two-handed ration/newspaper poses to NextBots and visual ghosts;
HL2 NPCs keep ordinary locomotion with only a clientside briefcase on their right-hand bone. The stock newspaper
replaces a hidden driving parcel and follows both hands; no extracted or new game assets are shipped. Small items can be stowed. Briefcases on both body types stay attached until a combat state, never drop as physical objects, and need no luggage sequences. The admin carried-item debugger can force an item onto a calm unarmed actor.

Direct attackers without a shared team are now added as enemies on the first hit, including during an existing fight. Police no longer use door holding; door breaching remains available.

Prop-chair seating now finishes the close approach below the route completion distance. Seated scenic NextBots no longer rise or drift under physics; ledge placement additionally checks direct pelvis support.

Ghost carried items were removed in both modes; server-ghost materialization suppresses automatic carry selection. The briefcase hangs upright from the finger grip; the newspaper follows the fingertips at its lower edge, has upright text and leans away from the face by 15 degrees. Render bounds include hand positions so close-up views do not cull the props.

The entity-cache warm-up on first player spawn was restored: BGN temporarily spawns configured NPCs and vehicles to warm their resources. NextBot relationships now use the most frequent disposition of each foreign NPC towards server players, with neutral ties, instead of hidden NPC probes. Ordinary HL2 NPC body relationships retain their existing rules. See [brains](systems/brains.md).

Local gang behavior change after the baseline above: walking packs of up to three; the capped random fight roster is replaced by support for all visible same-gang allies, including late arrivals. `bgn_gang_help_chance` is no longer used; `bgn_enemy_share_period` controls the support interval. See [gangs](systems/gangs.md).

Local debug UI addition: Spawnmenu Options now has a Debugging page with separate overlays, an admin-only
server actor inspector (recent states/reactions, weights and cached GOAP plan/facts), LOS/FOV visualization
and an actor camera with automatic release. See [debug controls](systems/testing.md#spawnmenu-debug-page).
The native follow-up enlarges/scales debug text, wraps inspector lines and preserves the camera when the
actor list is refreshed; overlay, visibility, path, damage, GOAP and camera checks were exercised in single-player.
Visual verification also fixed the NextBot camera falling to its feet (server-only eye method) and the
viewed head clipping into the camera; server eye frames and temporary body rendering suppression fix both.

Local debug redesign: editor/debug Tools now have separate categories. UID-based inspection defaults to one actor and records actual perception and team handoffs, with bounded history, configurable HUD/3D2D, distances, WH, filters and freeze. Cached line meshes replace the separate immediate world passes. Scene previews and hand markers share these controls; actor movement restores prior control flags/state. Gameplay stealth rules are unchanged. Native debugging also exposed and fixed carried-model culling after actor teleportation. See [debug controls](systems/testing.md#spawnmenu-debug-page).

A 2026-11-12 audit of the current branch against 1.13.7 (what stayed, what changed, what can break old behavior) is in [comparison with 1.13](migration.md).

## Reproduce the comparison

```text
git log --reverse --no-merges --oneline 2.3.0
git log --reverse --oneline 2.3.0..7459c3c7
git diff --stat 2.3.0 7459c3c7 -- lua docs
```

Read implementation and callers before changing a documented contract. Commit subjects alone do not prove behavior. [Maintenance rules](ai.md).

Local change: distant actor logic uses configurable staggered pause/active windows; see [LOD](systems/brains.md).

Local weapon change: NextBot pistol single/short bursts, witness-local police harm limits, lifecycle cleanup and armed arrest aim. See [brains](systems/brains.md).

Local network change: actor PVS sync sends identity (entity, type, generation, class, model, name, gender) only on first sight or rebind and otherwise only the changed state part; sends are capped at 8 per tick. See [architecture](architecture.md).

Local vehicle fix: forced ejection during car seizure now uses the original passengers rather than deep copies of their actors. Restored bodies keep their registered identity and AI instead of freezing and later being removed as orphans. See [vehicles](systems/vehicles.md).

Local vehicle fix 2: an actor leaving a moving car (police arriving at a chase) is immune to damage from that same car for 3 seconds, so a fast car no longer kills the officer on exit, after which the lifeless body stood still and was removed. See [vehicles](systems/vehicles.md).

Local 2.5.1 working-tree change (publication not verified): confirmed-damage conflict memory, attacker-only witnesses, caller-visible help, shared player/actor wanted thresholds, foreign hostility wanted and primary-officer arrest escalation. See [wanted](systems/wanted.md) and [arrest](systems/arrest.md).

Local follow-up: attacking an observer's known enemy does not incriminate a non-hostile attacker; existing enemy lists and bidirectional `D_HT` forbid the exception. It applies before initiator selection, also to arrest initiation/non-police harm counts. The observer's own enemies now count in `IsEnemyOfTeam`. See [conflicts](systems/wanted.md#conflict-memory-and-witnesses).

Local follow-up: an active police phone call no longer requires continuous LOS or stops because the target became wanted/police. Threat interruption is strictly below 300 units. Allied help and GOAP replanning preserve the active call; entry limits and completion filters remain. See [wanted](systems/wanted.md).
