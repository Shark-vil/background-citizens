# Server API

Run gameplay changes on SERVER. Many methods are declared in sh_ files for compatibility but depend on a server body, brain, provider or gameplay module.

`bgNPC.Actor.New(...)` is the unchecked class constructor; extensions should use `bgNPC.Actor.Create(...)`. `actor:StopStaticSequence()` is an alias of `ResetSequence()`.

## Actor

### AddEnemy

`actor:AddEnemy(ent, reaction, always_visible)`

Adds an entity enemy with optional reaction and always_visible flag; hooks, team rules may reject it.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/AddEnemy.md).

### AddTarget

`actor:AddTarget(ent)`

Adds a valid entity target unless already present; requires targets_controller.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/AddTarget.md).

### AddTeam

`actor:AddTeam(team_name)`

Adds a non-empty team name without duplicates.

Source: `lua/background_npcs_core/actor/components/sh_team.lua`.

### AvoidDVVehicle

`actor:AvoidDVVehicle(goal)`

Internal pedestrian detour update; returns whether avoidance is active.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### CallForHelp

`actor:CallForHelp(enemy)`

Asks nearby actors to react to enemy; visibility, teams and cooldown still apply.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/CallForHelp.md).

### CallStateAction

`actor:CallStateAction(state_name, func_name, ...)`

Calls a registered callback with this actor and extra arguments; nil state_name uses the current state.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/CallStateAction.md).

### CheckMoveUpdate

`actor:CheckMoveUpdate(tag, time)`

Per-tag throttle; first call returns false, later calls return true once the requested interval expires.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### ClearSchedule

`actor:ClearSchedule()`

Legacy body-specific schedule API; prefer WalkToPos/StopWalk.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/ClearSchedule.md).

### Create

`bgNPC.Actor.Create(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)`

Creates and registers an actor; returns the actor or nil for an invalid entity. Prefer bgNPC.Actor.Create(npc, npc_type); Create validates the entity and actor type before invoking the class constructor. Optional arguments: custom_uid, not_sync_actor_on_client, not_auto_added_to_list. Do not bind an entity twice.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### CreateFakePlayerMethodsForNPC

`actor:CreateFakePlayerMethodsForNPC()`

Internal compatibility adapter for NPCs; not an actor creation API.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### DropToFloor

`actor:DropToFloor()`

Delegates floor placement to the body or valid entity.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### EnemiesRecalculate

`actor:EnemiesRecalculate()`

Updates counts, drops dead/forgotten enemies and assigns the nearest to the body; requires a valid body.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/EnemiesRecalculate.md).

### EnterVehicle

`actor:EnterVehicle(vehicle)`

Accepts a valid vehicle entity (chassis); resolves or creates its BGN provider internally. Boarding is checked again after 0.5 seconds; no synchronous success result. Actor/UID persist, entity changes. Requires DV support and provider access.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Method page](../classes/actor/functions/EnterVehicle.md).

### ExitVehicle

`actor:ExitVehicle(forced)`

Returns true on a completed exit. A blocked exit retains the seat. Recreates the saved NPC/NextBot body.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Method page](../classes/actor/functions/ExitVehicle.md).

### Fear

`actor:Fear()`

Runs the fear mechanic only when enabled.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### FearScream

`actor:FearScream()`

Emits the configured fear voice when allowed.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/FearScream.md).

### FoldWeapon

`actor:FoldWeapon()`

Removes the active weapon unless disable_fold_weapon is set.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/FoldWeapon.md).

### GetActorWeapon

`actor:GetActorWeapon()`

Returns the assigned weapon class, not a weapon entity. That assignment is not part of the regular client snapshot.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/GetActorWeapon.md).

### GetBody

`actor:GetBody()`

Returns the server body adapter or nil. It is replaced across boarding/exiting.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetBrain

`actor:GetBrain()`

Returns the server brain or nil.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetClosestPointInRadius

`actor:GetClosestPointInRadius(radius)`

Returns the nearest navigation point around this actor, or nil.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/GetClosestPointInRadius.md).

### GetClosestPointToPoint

`actor:GetClosestPointToPoint(pos, radius)`

Returns a navigation point in radius closest to pos, or nil.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/GetClosestPointToPoint.md).

### GetDistantPointInRadius

`actor:GetDistantPointInRadius(radius)`

Returns the farthest navigation point around this actor, or nil.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/GetDistantPointInRadius.md).

### GetDistantPointToPoint

`actor:GetDistantPointToPoint(pos, radius)`

Returns a navigation point in radius farthest from pos, or nil.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/GetDistantPointToPoint.md).

### GetRandomState

`actor:GetRandomState()`

Returns a weighted at_random state name or none for empty/zero weights.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetRandomState.md).

### GetReactionForDamage

`actor:GetReactionForDamage(enemy)`

Chooses a damage reaction through the brain or weighted at_damage; wanted actors retreat instead of defense.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetReactionForDamage.md).

### GetReactionForProtect

`actor:GetReactionForProtect(enemy)`

Chooses at_protect reaction with cooldown and civilian participation checks.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetReactionForProtect.md).

### GetVehicle

`actor:GetVehicle()`

Returns the chassis or nil. Requires the server vehicle provider; use InVehicle for a client occupancy check.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Method page](../classes/actor/functions/GetVehicle.md).

### GetVehicleAI

`actor:GetVehicleAI()`

Returns the DV controller or nil; requires the server provider.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Method page](../classes/actor/functions/GetVehicleAI.md).

### GetVehicleGroup

`actor:GetVehicleGroup()`

Returns the first configured group, or police/taxi/residents fallback.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

### GetWalkPos

`actor:GetWalkPos()`

Returns the current position goal or nil.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### GetWalkTarget

`actor:GetWalkTarget()`

Returns the followed entity (possibly NULL).

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### GiveWeapon

`actor:GiveWeapon(weapon_class)`

Changes the assigned weapon class; does not equip it immediately. nil clears the assignment.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### Init

`actor:Init(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)`

Internal constructor used by the class system. Use bgNPC.Actor.Create instead.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### IsCivilian

`actor:IsCivilian()`

Returns true for residents that are not police.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

### IsExecutingCombatSchedule

`actor:IsExecutingCombatSchedule()`

Checks whether the server body is busy shooting/reloading.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### IsSequenceFinished

`actor:IsSequenceFinished()`

Checks animation completion, respecting loop duration.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/IsSequenceFinished.md).

### IsSequenceLoopFinished

`actor:IsSequenceLoopFinished()`

Checks the loop deadline; an unlimited active loop is not finished.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/IsSequenceLoopFinished.md).

### IsStateDelay

`actor:IsStateDelay()`

Checks local state_delay; this deadline is not in the regular client snapshot. Use on the server.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/IsStateDelay.md).

### IsStayingOut

`actor:IsStayingOut()`

Checks the stay-out deadline.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

### IsWanted

`actor:IsWanted()`

Queries the server wanted module for the current entity.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

### PlayNextStaticSequence

`actor:PlayNextStaticSequence()`

Consumes the queued animation; returns whether it started processing it.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/PlayNextStaticSequence.md).

### PlayStaticSequence

`actor:PlayStaticSequence(sequence_name, loop, loop_time, action)`

Returns boolean; loop_time nil or 0 loops indefinitely. Requires a body and supported sequence. An action callback returning true can reject stopping.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/PlayStaticSequence.md).

### PoliceFights

`actor:PoliceFights(enemy)`

Checks whether nearby police already fight enemy for civilian participation rules.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

### PrepareWeapon

`actor:PrepareWeapon(weapon_class, switching)`

Equips/selects weapon_class or the assigned weapon through bgNPC.Combat.EquipActor.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/PrepareWeapon.md).

### RandomState

`actor:RandomState()`

Chooses and applies a weighted at_random state unless PreRandomState cancels; returns the resulting state name.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/RandomState.md).

### RecalculationTargets

`actor:RecalculationTargets()`

Removes invalid target entries. This is the implemented name; TargetsRecalculate is not defined.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/RecalculationTargets.md).

### Remove

`actor:Remove()`

Unregisters the actor and removes its current entity.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### RemoveActor

`actor:RemoveActor()`

Unregisters once, stops the brain and releases its vehicle provider. Does not itself remove the entity.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### RemoveAllEnemies

`actor:RemoveAllEnemies()`

Calls enemy removal hooks, then clears remaining enemy storage.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/RemoveAllEnemies.md).

### RemoveAllTargets

`actor:RemoveAllTargets()`

Calls target removal hooks, then forcibly clears any remaining targets.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/RemoveAllTargets.md).

### RemoveEnemy

`actor:RemoveEnemy(ent, index)`

Removes by entity or index (index takes priority); hooks can reject removal. Returns remaining count.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/RemoveEnemy.md).

### RemoveTarget

`actor:RemoveTarget(ent, index)`

Removes a target by entity or index (index takes priority); returns the remaining count.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/RemoveTarget.md).

### ResetSequence

`actor:ResetSequence()`

Stops static animation unless the callback rejects it or chains another animation.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/ResetSequence.md).

### ResetStateDelay

`actor:ResetStateDelay()`

Clears the state-transition deadline.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/ResetStateDelay.md).

### Say

`actor:Say(say_text, say_time, voice_sound, animation_sequence)`

Broadcasts text (default 5 seconds), optionally emits a sound and plays an animation.

Source: `lua/background_npcs_core/actor/components/sh_speech.lua`.

[Method page](../classes/actor/functions/Say.md).

### SayReplic

`actor:SayReplic(replic_id, replic_index, say_time, voice_sound, animation_sequence)`

Broadcasts a phrase ID/index for client localization; missing phrases are ignored.

Source: `lua/background_npcs_core/actor/components/sh_speech.lua`.

### SetGender

`actor:SetGender(gender_name)`

Sets the actor gender string. Regular server sync propagates it.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/SetGender.md).

### SetName

`actor:SetName(name)`

Sets the actor name string; nil leaves it unchanged. Regular server sync propagates it.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/SetName.md).

### SetNextSequence

`actor:SetNextSequence(sequence_name, loop, loop_time, action)`

Queues one sequence with loop settings and optional callback.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/SetNextSequence.md).

### SetReaction

`actor:SetReaction(reaction)`

Stores a reaction string or nil; does not execute it.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/SetReaction.md).

### SetSchedule

`actor:SetSchedule(schedule)`

Legacy numeric engine schedule API; NextBots map only supported schedules.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/SetSchedule.md).

### SetState

`actor:SetState(state, data, forced)`

Returns the new {state, data} table or nil when rejected. state=nil means none. forced bypasses normal locks/delays/validator, but mechanics/alive checks and pre-hooks can still reject the transition.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/SetState.md).

### SetStateDelay

`actor:SetStateDelay(time)`

Blocks ordinary state transitions for time seconds from CurTime().

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/SetStateDelay.md).

### SetTeam

`actor:SetTeam(team_data)`

Replaces this actor’s team list; nil clears it.

Source: `lua/background_npcs_core/actor/components/sh_team.lua`.

### SetWalkType

`actor:SetWalkType(move_type)`

Accepts walk, run, a numeric schedule, or nil (walk).

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/SetWalkType.md).

### ShouldExitVehicle

`actor:ShouldExitVehicle()`

Evaluates server dismount conditions; does not perform the exit.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

### StateLock

`actor:StateLock(lock)`

Sets the transition lock; nil/false unlocks.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/StateLock.md).

### StayOutOfFight

`actor:StayOutOfFight(time)`

Suppresses defense participation for time seconds (default 15) and resets the GOAP plan.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

### StopWalk

`actor:StopWalk()`

Clears goals, chase and DV detour, then resets walk type.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/StopWalk.md).

### SyncFunction

`actor:SyncFunction(name, ply, data)`

Server-only compatibility sender: bgNPC.Net.Send(name, ply, self.uid, data). Receive with bgNPC.Net.Receive; SNet is no longer required.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/SyncFunction.md).

### TakeVehicleDamage

`actor:TakeVehicleDamage(amount, attacker, inflictor)`

Applies occupant damage through reaction hooks and stored character health; lethal damage emits death hooks and removes the actor.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

### Think

`actor:Think()`

Legacy entry point; the normal actor update service owns brain updates. Do not add a duplicate Think loop.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### UpdateMovement

`actor:UpdateMovement()`

Internal scheduled path-following service; do not add a second update loop.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/UpdateMovement.md).

### UpdateStateData

`actor:UpdateStateData(data)`

Replaces the current state data table; does not merge it.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/UpdateStateData.md).

### Voice

`actor:Voice(voice_id, fallback)`

Broadcasts a voice event; each client selects its own language/fallback. Combat/contact events are throttled per actor.

Source: `lua/background_npcs_core/actor/components/sh_speech.lua`.

### VoiceSay

`actor:VoiceSay(sound_path, sound_level, pitch_percent, volume, channel, sound_flags, dsp)`

Emits an explicit sound on the current entity using EmitSound defaults.

Source: `lua/background_npcs_core/actor/components/sh_speech.lua`.

[Method page](../classes/actor/functions/VoiceSay.md).

### WalkDestinationExists

`actor:WalkDestinationExists()`

Checks for a position or valid followed target.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### WalkToPos

`actor:WalkToPos(pos, move_type, path_type)`

Starts travel to a Vector or node:GetPos(); nil stops. Requires a navigable path. Finishing is reported through BGN_ActorFinishedWalk.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/WalkToPos.md).

### WalkToTarget

`actor:WalkToTarget(target, move_type, path_type)`

Follows an entity with periodic path rebuilds; nil/invalid target stops.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/WalkToTarget.md).

### Walking

`actor:Walking()`

Reports body movement; body adapters only exist on the server.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Method page](../classes/actor/functions/Walking.md).

## Namespaces and services

| API | Contract / source |
|---|---|
| `bgNPC:SpawnActor(npc_type, desiredPosition, enableSpawnEffect, require_hidden)` | Creates an actor; implementation in `spawner/sv_spawner.lua`; check result before use. |
| `bgNPC.Statistics.AddKill(attacker, actor)` | Adds and synchronizes a kill count. |
| `bgNPC.Statistics.Reset(attacker)`, `ResetAll()` | Clears and synchronizes statistics. |
| `bgNPC.Actors.Rebind(actor, npc)` | Internal body replacement; updates registries/references and emits `BGN_ActorEntityChanged`. Use the normal vehicle lifecycle instead of calling directly. |
| `bgNPC.Combat` | Weapon skill/equipment, fighting checks, resolving vehicle attackers and enemies: `api/sv_combat.lua`. |
| `bgNPC.Nav` | Provider selection, loading and pathfinding: `nav/sv_nav.lua`; see [navigation](../systems/navigation.md). |
| `bgNPC.GOAP` | Planner actions/sensors: see [brains](../systems/brains.md). |
| `bgNPC.Tasks` | Cooperative work with yield/wait/budget; `core/sh_tasks.lua`. Each realm has its own scheduler. |

`bgNPC.Combat.CanPoliceUseStunstick(officer, suspect)` returns the SERVER baton eligibility from wanted status, kill evidence and that officer's witnessed harm. `bgNPC.Combat.ResetPoliceThreat(suspect)` clears kill evidence/counters and officer harm records; use only for a completed reset, not initial wanted escalation. `BGN_PostVehicleDamage(actor, attacker, amount)` fires on SERVER after virtual seated health is updated, before death handling.
