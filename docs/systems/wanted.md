# Wanted levels and offenders

Sources: `systems/wanted/`, `systems/sv_offender.lua`, `config/states/sh_wanted.lua`. The server owns wanted state and reactions; clients receive records and render the HUD/halos.

| Server cvar | Default | Purpose |
|---|---|---|
| `bgn_enable_wanted_mode` | `1` | Enables wanted behavior; changing it clears existing wanted entries. |
| `bgn_wanted_time` | `30` | Base wanted duration in seconds. |
| `bgn_wanted_level` | `1` | Allows level escalation (up to level 5). |
| `bgn_wanted_level_up_period` | `60` | Seconds between automatic level-ups of a wanted NPC/actor (never a player); needs `bgn_wanted_level`; `0` disables. |
| `bgn_wanted_police_instantly` | `1` | Enables immediate police response handling. |
| `bgn_wanted_impunity_limit` | `5` | Impunity threshold used by wanted actions. |
| `bgn_wanted_impunity_reduction_period` | `10` | Seconds between impunity reductions. |

Kills, witnesses, police calls and arrest refusal feed wanted handling. Ignored/arrested players and medic actors are excluded from new wanted entries. Actor wanted identity survives DV body replacement. While any resident is within 600 units of the target or sees it within `bgn_wanted_detection_radius`, the timer is reset every second and does not run, for players and actors alike; a car the target sits in counts as the target for the sight check. A non-player wanted target that stays 15 seconds outside every player's field of view, or farther than half of `bgn_spawn_radius_visibility` (obstacles are not checked), is dropped; this is separate from player wanted expiry and population removal.

A resident who kills a resident or damages a police car by ramming becomes an offender (the officers react to a ram by an actor-driven car only with 10% per hit; otherwise it is ignored and does no damage to them, `modules/dv/sv_car_damage_reaction.lua`): it loses residents and gains offenders in its own configuration copy. The team is not automatically restored when wanted expires. Witnessed crimes can also create wanted state when enabled. See [brains](brains.md) for reactions and [arrest](arrest.md) for surrender/refusal.

## Integration

Obtain `local wanted = bgNPC.Modules.Get('wanted')` after systems load; it may be nil before then or in a different realm. Query `wanted:HasWanted(entity)`, `GetWanted(entity)` and `GetAllWanted()`. Change state on SERVER with `AddWanted(entity, time)` and `RemoveWanted(entity)`; adding an existing target does not reset or extend its timer. The returned wanted record supports `UpdateWanted(time)`, `SetLevel(level)`, `LevelUp()` and `LevelDown()`; nonpositive SetLevel removes wanted, levels above 5 are capped.

Hooks include `BGN_AddWantedTarget`, `BGN_RemoveWantedTarget`, `BGN_WantedLevelUp`, `BGN_WantedLevelDown`. The server sends existing records to a player on `BGN_PlayerReady`. Client UI options do not disable the authoritative server system.

## Conflict memory and witnesses

SERVER keeps one directed record per pair in the existing `first_attacker` module. Only confirmed positive damage creates a record; vehicles resolve to their driver. Retaliation refreshes the timestamp without reversing the initiator. A defender can still initiate a separate conflict against someone else. Same-team actors and the existing consensual brawl are excluded. Residents/police do not blame a retaliating victim unless it is already a threat to their team. A player attacking a foreign NPC/NextBot with `Disposition(player) == D_HT` is defending against that entity; missing `Disposition` is safe.

Before blaming an initiator, every actor applies the common-enemy rule: if the damaged target is already in that observer's enemy list, the hit does not make its attacker an enemy. This exception is refused when observer and attacker already list one another as enemies in either direction, or there is `D_HT` between observer and attacker in either direction (configured relationships, body dispositions and available entity `Disposition` methods). It creates no permanent alliance and clears no enemy entries. For example, a neutral gangster shooting a player already hunted by police is not blamed for the first hit, even without wanted status. Factual pair initiator memory is still kept; a later attack on an uninvolved ally is a separate offense. `IsEnemyOfTeam` includes the observer's own enemy list as well as its teammates.

Damage witnesses must see the attacker within 2500 units, with LOS and, for attacking actors, FOV. Seeing only the victim or knowing wanted status does not bypass this. Other teams protect their allies; residents/police also resolve conflicts between outsiders. Enemy assignment and wanted status are separate. `CallForHelp` shares a threat with teammates within 1000 units who see the caller, without requiring enemy visibility or FOV; periodic sharing keeps its existing team/gang rules.

Records expire after 60 seconds without damage or LOS between the participants (either direction, no FOV). Death, completed arrest and wanted removal clear every record involving that entity in either role. DV body replacement transfers both roles and the impunity counter. This memory is server-only, not a client snapshot.

## Initial wanted assignment

With wanted enabled and peaceful mode off, players and actors not currently in residents share the main kill handler's witnessed-kill impunity threshold (`>= bgn_wanted_impunity_limit`, `0` disables), reduced by one each `bgn_wanted_impunity_reduction_period` seconds (`0` disables decay). Counts concern killed actors. Instant wanted for killing a police actor additionally requires another living police actor to see the killer with LOS and FOV within 2500 units; the dying officer and killer cannot be witnesses. Ordinary threshold kills also require a witness with LOS/FOV.

A foreign entity (neither player nor actor) becomes wanted without a witness if it kills any residents/police actor, or has `Disposition(actor) == D_HT` towards any living residents/police actor. Hostility is polled once per second; `bgn_ignore_another_npc` disables this polling. For local enemy detection, a hostile foreign entity must be within 2500 units and LOS; FOV is not required. Foreign NPC dispositions towards ordinary actor bodies are preserved instead of being replaced from player relations; the existing NextBot player-disposition adapter remains in use. There is no guessed hostility for entities without `Disposition`.

Completed witness calls, police radio backup and existing civilian-offender paths remain wanted sources. Medics and existing ignored/arrested exclusions remain protected. Arrest escalation is described on the [arrest page](arrest.md#escalation-during-an-arrest). Wanted assignment still informs all police immediately.

<a id="behavior-decision-tree"></a>

## Behavior decision tree

The optional [held-weapon reaction](brains.md#lethal-weapons) is a separate SERVER input, without damage:

```text
Actor killed → inspect last damage and the killer's current active weapon
├─ Explosion / vehicle damage / player killing from a vehicle → do not learn
└─ Same attacker + valid active weapon + new class → cache it, rewrite DATA (even with checkbox off)

Once per second: bgn_react_to_lethal_weapon = 1, non-peaceful mode
├─ Living player/NPC/NextBot holds a class from the cache
└─ Living residents/police observer; not self, teammate or existing enemy
   ├─ Ignored player / player in friend mode / beyond 800 / outside FOV / blocked LOS → skip
   └─ Pick at_damage reaction
      ├─ ignore/none or AddEnemy rejected → no new state
      └─ Enemy accepted → store reaction; if calm, clear targets and change state
         └─ Holstering/disabling does not clear enemies; normal memory applies
```

This input assigns no wanted level directly. Existing police calls and sharing can propagate the threat.

This is the implemented **SERVER** tree in the local 2.5.1 implementation on `dev`; it does not establish a Workshop release. CLIENT receives wanted records but does not determine guilt. `O` is the observer, `A` the attacker and `V` the damaged target. LOS checks obstacles; the damage-witness FOV check requires the attacker to be strictly in front of the observer's eye/forward direction (including NextBot bodies).

```text
Damage attempt
├─ Existing personal/team/mode/protection hooks may block damage
│  └─ The victim's own reaction can happen here, before health changes
└─ Positive actual damage (engine or virtual seated health)
   ├─ Invalid participant/ignored attacker, self-hit or consensual brawl → stop this notification
   ├─ Living pair (except same-team ACTOR pairs) → record first A → V, or refresh time
   │  └─ Response V → A never reverses the saved roles
   ├─ Friend mode with a player involved → keep its separate reaction override
   ├─ A already under arrest → evaluate confirmed-harm escalation first
   └─ Emit BGN_ConfirmedDamage
      ├─ Police handler → try to start/continue arrest
      ├─ Witness handler → determine a local enemy and reaction
      └─ Wanted handler → refresh an existing wanted timer
```

The last three items are subscribers, not a guaranteed order between hook handlers. Pair recording and existing-arrest harm checks precede that notification. Fatal hits need not create a new live-pair record; death/wanted callbacks have their own paths. See the [arrest tree](arrest.md#arrest-decision-tree).

```text
Damage witness O
├─ O is A/V, dead, too far (>2500), or cannot see A through LOS → skip
├─ A is an ACTOR outside O's FOV → skip (players/foreign entities need no FOV)
├─ Both sides share O's team → skip
├─ Neither side shares O's team, and O is not residents/police → skip
└─ Eligible witness
   ├─ If only A is a teammate, swap A/V for the resolver
   │  └─ Visibility above was checked against the actual attacker before this swap
   ├─ ResolveEnemy(O, V, A) → no choice → no new enemy/reaction for this hit
   └─ ResolveEnemy returns a side
      ├─ Protection cooldown / hook veto → no enemy
      ├─ Calm O picks ignore/none → no enemy
      └─ Choose configured reaction and request AddEnemy
         └─ Final guards can refuse: peaceful mode, team, mechanics,
            ignored entity, arrest/medic protections or another hook
```

For a direct resolver call, `A`/`V` are the supplied sides; the witness normalization above is not performed inside `ResolveEnemy`. The first matching rule wins:

| Priority | Condition | Resolver result |
|---|---|---|
| 1 | Unsupported participant type | None. |
| 2 | V is already O's enemy; A and O have no enemy-list hostility or `D_HT` in either direction; V is not O itself | None: the common-enemy exception. |
| 3 | Both sides are teammates of O | None. |
| 4 | O is residents/police and V was first to attack A | If A is a threat to O's team, choose A unless A is a teammate; otherwise choose V unless V is a teammate. A teammate result means none. |
| 5 | Only A is O's teammate | V. |
| 6 | Only V is O's teammate | A. |
| 7 | Player A attacks foreign NPC/NextBot V | V if its available `Disposition(A)` is `D_HT`; otherwise A. |
| 8 | Foreign non-player A attacks player V | A. |
| 9 | A is wanted, otherwise V is wanted | A first, otherwise V. |
| 10 | O is residents/police and A was first to attack V | A. |
| 11 | V is a threat to O's team, otherwise A is | V first, otherwise A. Includes O's own enemy list and existing team conflict evidence. |
| 12 | ACTOR A does not list V as an enemy, otherwise ACTOR V does not list A | V first, otherwise A. |
| 13 | A player participates and the pair has a saved initiator | The saved initiator. |
| 14 | No rule matched | None. |

`D_HT` disables the common-enemy exception; it does not force the resolver to choose A ahead of every later rule. Existing enemy lists are never cleared by the exception. The personal victim reaction, wanted broadcasts, help and scripted enemy assignments are separate entry points, not globally filtered by this resolver.

```text
Other ways to learn an enemy
├─ Foreign entity has direct D_HT towards a living ACTOR
│  ├─ Within 2500 + LOS, without FOV → local enemy/reaction request
│  └─ That ACTOR is residents/police → wanted request without a witness
│     (poll every second; peaceful/ignore-other-NPC modes stop the poll)
├─ CallForHelp → living teammates within 1000 who see the caller, no FOV
│  └─ Help mechanics, arrest veto, protection cooldown and AddEnemy guards still apply
├─ Periodic sharing → existing source/team/gang visibility rules
└─ Wanted broadcast / police backup → independent police notification
```

```text
Initial wanted request from built-in gameplay
├─ Arrest refusal/escape/harm/kill → follow the arrest tree
├─ Completed witness phone call → report eligible known enemies
│  └─ Police already know the enemy / hook veto / failed call → no new report
├─ Police radio backup / civilian-offender path → their existing conditions
└─ An ACTOR was killed
   ├─ Peaceful mode, wanted disabled, or invalid killer → stop this kill handler
   ├─ Killer is still a residents ACTOR → stop this handler (offender path is separate)
   ├─ Killer already wanted → refresh timer / evaluate level-up
   ├─ Killer is neither player nor ACTOR
   │  └─ Victim is residents/police → wanted, no witness required
   └─ Player / other ACTOR killer
      ├─ No other living ACTOR sees the killer with LOS + FOV within 2500 → stop
      ├─ Instant-police-kill enabled + police victim + police witness → wanted
      ├─ Enabled impunity threshold reached (>=, default 5) → wanted
      └─ Otherwise → retain the witnessed-kill count if threshold counting is enabled
```

New entries still pass through `AddWanted` exclusions for ignored/arrested entities and medic actors. Assignment informs all police; it does not imply each officer witnessed the crime. Manual API calls and third-party hooks are outside this built-in trigger tree.

### Consequences of the priority order

| Situation | Current outcome |
|---|---|
| Neutral gangster hits a player already in the observer's enemies | No new enemy or arrest solely for this hit; player wanted status is unnecessary. Another observer without that knowledge can decide differently. |
| The gangster is already hostile to the observer | The exception is unavailable; normal resolver priorities apply. The old enemy is not forgiven. |
| A previously protected shooter attacks an uninvolved ally | Re-evaluate this new pair; the shared opponent gave no lasting immunity. |
| A non-hostile suspect hurts the primary officer's known enemy during arrest | Excluded from non-police injury/victim limits; killing still escalates separately. |
| First-attacker memory expires | It removes pair evidence, not all enemy lists or an active wanted record. Those have separate lifetimes. |

Sources: `api/sv_combat.lua`, `actor/events/sv_self_damage.lua`, `actor/events/sv_damage_reaction.lua`, `systems/sv_first_attacker_found.lua`, `systems/sv_relationship.lua`, `systems/wanted/sv_wanted_actions.lua`, `systems/wanted/sh_wanted_class.lua`. See [conflict memory](#conflict-memory-and-witnesses) for resets and [arrest](arrest.md) for weapon choice.

## Completing a police call

Once `calling_police` has started, losing LOS, the target becoming wanted or belonging to police do not abort its 7–15 second countdown. The threat-related cancellation is distance strictly below 300 units to the current nearest enemy; exactly 300 does not cancel. Allied `CallForHelp` can add enemy knowledge without changing the caller's state, and GOAP leaves the active call to the FSM. Missing enemies/invalid targets and disabling wanted still end the state safely. Entry limits remain: at most two callers near a player, no new call when police already know the selected enemy, and wanted mode must be enabled. Completion still filters enemies through police knowledge and `BGN_PreCallingPolice`, then normally enters `fear`; finishing the animation does not guarantee a new wanted entry.
