# Shared API

Loaded in both realms. Client reads reflect received data, not an authoritative simulation. Check for a missing actor and validate its entity.

## Actor

### EnemiesCount

`actor:EnemiesCount()`

Returns the tracked enemy count.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/EnemiesCount.md).

### EqualStateGroup

`actor:EqualStateGroup(group_name)`

Checks the current state against a group name or list.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/EqualStateGroup.md).

### GetActiveWeapon

`actor:GetActiveWeapon()`

Returns a weapon entity or NULL; a seated visual may have no active weapon.
Carried parcels, suitcases/briefcases and newspapers return NULL through this actor API; the native entity can still expose them.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/GetActiveWeapon.md).

### GetAngles

`actor:GetAngles()`

Returns current entity angles, or Angle(0, 0, 0) if unavailable.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetClass

`actor:GetClass()`

Returns the original character class, not necessarily the current visual entity class.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetClass.md).

### GetData

`actor:GetData()`

Returns this actor’s mutable configuration copy; changing it affects this actor. Global config changes do not update existing actors.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetData.md).

### GetEnemy

`actor:GetEnemy()`

Returns the selected living enemy or NULL: a direct attacker from the last 5 seconds, then the siege/squad target, then the previous valid combat target, then the nearest living enemy. GetNearEnemy remains the distance-only query. CLIENT uses only its received local data; SERVER owns combat selection.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/GetEnemy.md).

### GetFirstEnemy

`actor:GetFirstEnemy()`

Returns the first valid enemy or NULL.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/GetFirstEnemy.md).

### GetFirstTarget

`actor:GetFirstTarget()`

Returns the first target entry or NULL.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/GetFirstTarget.md).

### GetGender

`actor:GetGender()`

Returns the stored gender or unknown.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetGender.md).

### GetGenderByModel

`actor:GetGenderByModel()`

Infers gender from the character model (saved model while seated); no argument. Returns female, male or unknown.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetGenderByModel.md).

### GetHealth

`actor:GetHealth()`

Alias in behavior for Health(); use instead of assuming GetNPC():Health exists.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetHealth.md).

### GetLastEnemy

`actor:GetLastEnemy()`

Returns the last valid enemy or NULL.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/GetLastEnemy.md).

### GetLastReaction

`actor:GetLastReaction()`

Returns the last stored reaction.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetLastReaction.md).

### GetLastTarget

`actor:GetLastTarget()`

Returns the last target entry or NULL.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/GetLastTarget.md).

### GetMaxHealth

`actor:GetMaxHealth()`

Returns the body/entity maximum or saved occupant maximum; 0 when unavailable.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetMaxHealth.md).

### GetNPC

`actor:GetNPC()`

Returns the current entity, possibly NULL during replacement. In a car it is a DV visual entity. Fetch it again after BGN_ActorEntityChanged and validate with IsValid.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetNPC.md).

### GetName

`actor:GetName()`

Returns the stored display name.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetName.md).

### GetNearEnemy

`actor:GetNearEnemy()`

Returns the nearest valid enemy or NULL.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/GetNearEnemy.md).

### GetNearTarget

`actor:GetNearTarget()`

Returns the nearest valid target entity or NULL.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/GetNearTarget.md).

### GetOldState

`actor:GetOldState()`

Returns the previous state name.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetOldState.md).

### GetOldStateData

`actor:GetOldStateData()`

Returns the previous state data table; client snapshots do not carry full server state data.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetOldStateData.md).

### GetPos

`actor:GetPos()`

Returns the current entity position, or Vector(0, 0, 0) if unavailable.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetRelationship

`actor:GetRelationship(value, default)`

Returns the configured relationship for an entity/actor, falling back to default.

Source: `lua/background_npcs_core/actor/components/sh_team.lua`.

### GetState

`actor:GetState()`

Returns the current state name.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetState.md).

### GetStateData

`actor:GetStateData()`

Returns the current mutable state data table; client snapshots contain only the state name.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetStateData.md).

### GetStateGroupName

`actor:GetStateGroupName()`

Returns the registered group of the current state.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/GetStateGroupName.md).

### GetTarget

`actor:GetTarget(index)`

Returns the target at index (default 1), or NULL.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/GetTarget.md).

### GetType

`actor:GetType()`

Returns the actor configuration ID, for example citizen.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/GetType.md).

### HasActiveWeapon

`actor:HasActiveWeapon()`

Returns whether GetActiveWeapon yields a valid entity.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### HasEnemy

`actor:HasEnemy(ent)`

Returns whether ent is in the enemy list.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Method page](../classes/actor/functions/HasEnemy.md).

### HasNoEnemies

`actor:HasNoEnemies()`

Returns true when the enemy count is zero.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

### HasNoTargets

`actor:HasNoTargets()`

Returns true when the target count is zero.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

### HasSequence

`actor:HasSequence(sequence_name)`

Case-insensitive check of the stored sequence name.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/HasSequence.md).

### HasState

`actor:HasState(state)`

Accepts a state name or list of names; returns boolean.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/HasState.md).

### HasStateGroup

`actor:HasStateGroup(state_name, group_name)`

Checks a specified state against a group name or list.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/HasStateGroup.md).

### HasTarget

`actor:HasTarget(ent)`

Returns whether ent occurs in the target list.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/HasTarget.md).

### HasTeam

`actor:HasTeam(value)`

Accepts a team name/list/entity/actor. Gang membership has special rules; do not infer alliance solely from the bandits tag.

Source: `lua/background_npcs_core/actor/components/sh_team.lua`.

[Method page](../classes/actor/functions/HasTeam.md).

### Health

`actor:Health()`

Returns character health, including stored occupant health. Returns 0 when unavailable; safe in both realms.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/Health.md).

### InVehicle

`actor:InVehicle()`

Server checks the provider; client reads bgn_vehicle_entered on the current entity.

Source: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Method page](../classes/actor/functions/InVehicle.md).

### IsAlive

`actor:IsAlive()`

Returns whether the character is alive; on the server a dead actor is also unregistered.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/IsAlive.md).

### IsAnimationPlayed

`actor:IsAnimationPlayed()`

Checks the actor animation flag and Animator state.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/IsAnimationPlayed.md).

### IsLoopSequence

`actor:IsLoopSequence()`

Returns the stored animation-loop flag.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/IsLoopSequence.md).

### IsMeleeWeapon

`actor:IsMeleeWeapon()`

Checks the active/assigned class against configured melee weapons; no class returns false.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Method page](../classes/actor/functions/IsMeleeWeapon.md).

### IsNPC

`actor:IsNPC()`

Checks whether the current entity is an engine NPC.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### IsNextBot

`actor:IsNextBot()`

Checks whether the current entity is a NextBot.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

### IsStateLock

`actor:IsStateLock()`

Returns the stored lock flag.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Method page](../classes/actor/functions/IsStateLock.md).

### IsValid

`actor:IsValid()`

Checks the current entity only; not equivalent to alive.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Method page](../classes/actor/functions/IsValid.md).

### IsValidSequence

`actor:IsValidSequence(sequence_name)`

Checks model sequence availability; false while seated.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Method page](../classes/actor/functions/IsValidSequence.md).

### TargetsCount

`actor:TargetsCount()`

Returns the tracked target count.

Source: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Method page](../classes/actor/functions/TargetsCount.md).

## actors

Source: `lua/background_npcs_core/api/sh_actors.lua`.

| Signature |
|---|
| `bgNPC.Actors.Get(npc)` |
| `bgNPC.Actors.IsActor(npc)` |
| `bgNPC.Actors.GetByUid(uid)` |
| `bgNPC.Actors.GetFirst()` |
| `bgNPC.Actors.GetAll()` |
| `bgNPC.Actors.Count(actor_type)` |
| `bgNPC.Actors.GetByType(actor_type)` |
| `bgNPC.Actors.GetAllNPCs()` |
| `bgNPC.Actors.GetNPCsByType(actor_type)` |
| `bgNPC.Actors.HasNPC(npc)` |
| `bgNPC.Actors.Filter(predicate)` |
| `bgNPC.Actors.GetByTeam(team)` |
| `bgNPC.Actors.GetByState(state)` |
| `bgNPC.Actors.GetInRadius(center, radius)` |
| `bgNPC.Actors.GetNearest(center)` |
| `bgNPC.Actors.GetNearestByType(center, actor_type)` |
| `bgNPC.Actors.ShareTeam(npc1, npc2)` |

## config

Source: `lua/background_npcs_core/api/sh_config.lua`.

| Signature |
|---|
| `bgNPC.Config.GetActor(actor_type)` |
| `bgNPC.Config.GetActorTypes()` |
| `bgNPC.Config.ActorExists(actor_type)` |
| `bgNPC.Config.ClearCache()` |
| `bgNPC.Config.SaveDefaults()` |
| `bgNPC.Config.Reset()` |
| `bgNPC.Config.GetWantedLevel(data)` |
| `bgNPC.Config.IsTypeActive(actor_type)` |
| `bgNPC.Config.GetFullness(actor_type)` |
| `bgNPC.Config.GetTypeLimit(actor_type)` |

## states

Source: `lua/background_npcs_core/api/sh_states.lua`.

| Signature |
|---|
| `bgNPC.States.Register(state_name, group_name, callbacks)` |
| `bgNPC.States.Exists(state_name)` |
| `bgNPC.States.GetGroup(state_name)` |
| `bgNPC.States.Call(state_name, func_name, ...)` |
| `bgNPC.States.HasAction(state_name, func_name)` |

## modes

Source: `lua/background_npcs_core/api/sh_modes.lua`.

| Signature |
|---|
| `bgNPC.Modes.IsPeaceful()` |
| `bgNPC.Modes.IsFriend()` |
| `bgNPC.Modes.IsAggressive()` |

## vision

Source: `lua/background_npcs_core/api/sh_vision.lua`.

| Signature |
|---|
| `bgNPC.Vision.HasLineOfSight(watcher, ent, channel)` |
| `bgNPC.Vision.NPCCanSeePos(ent, pos, fov)` |
| `bgNPC.Vision.PlayerCanSeePos(ply, pos, radius)` |
| `bgNPC.Vision.AnyActorSees(ent, exclude)` |
| `bgNPC.Vision.ActorsThatSee(ent)` |

`channel` is an optional diagnostic label (default `los`). It does not change the LOS predicate or its boolean/hit-entity returns. SERVER records the existing result only for subscribed actors with the vision layer enabled; CLIENT does not send sight telemetry.

## statistics

Source: `lua/background_npcs_core/api/sh_statistics.lua`.

| Signature |
|---|
| `bgNPC.Statistics.Get(attacker, actor_type)` |
| `bgNPC.Statistics.GetSum(attacker)` |

## assert

Source: `lua/background_npcs_core/api/sh_assert.lua`.

| Signature |
|---|
| `bgNPC.Assert.Arg(index, value, spec, func_name)` |
| `bgNPC.Assert.Field(owner_name, field_name, value, spec)` |
| `bgNPC.Assert.True(condition, message, ...)` |
| `bgNPC.Assert.NonEmptyString(index, value, func_name)` |
| `bgNPC.Assert.Is(value, spec)` |
| `bgNPC.Assert.RegisterType(type_name, checker)` |

## core

Source: `lua/background_npcs_core/api/sh_core.lua`.

| Signature |
|---|
| `bgNPC.Combat.IsIgnored(ent)` |
| `bgNPC.Util.GetCVar(name)` |
| `bgNPC.Util.IsDebug()` |
| `bgNPC.Util.Log(message, tag)` |
| `bgNPC.Util.IsVectorInWater(pos)` |
| `bgNPC.Util.GetActivePlayerTool(tool_name, ply)` |
| `bgNPC.Util.Warning(message)` |
| `bgNPC.Modules.Get(module_name)` |
| `bgNPC.Modules.Register(module_name, module_table)` |

## points

Source: `lua/background_npcs_core/api/sh_points.lua`.

| Signature |
|---|
| `bgNPC.Points.Count()` |
| `bgNPC.Points.GetAll(link_type)` |
| `bgNPC.Points.GetInRadius(center, radius, link_type)` |
| `bgNPC.Points.GetRandom(center, radius, link_type)` |
| `bgNPC.Points.GetClosestInRadius(center, radius, link_type)` |
| `bgNPC.Points.GetDistantInRadius(center, radius, link_type)` |
| `bgNPC.Points.GetIndexesInRadius(center, radius, link_type)` |
| `bgNPC.Points.GetClosestInChunk(center, link_type)` |
| `bgNPC.Points.GetDistantInChunk(center, link_type)` |
| `bgNPC.Points.GetClosestToPosInChunk(center, pos, link_type)` |
| `bgNPC.Points.GetDistantToPosInChunk(center, pos, link_type)` |
| `bgNPC.Points.FindPath(start_pos, end_pos, iteration_limit, link_type, actor)` |

## Data contracts

- `Actors.Get`, `GetByUid`, `GetFirst` and nearest lookups can return nil. `GetAll`, type lists and NPC lists expose internal storage: do not mutate them.
- `Config.GetActor` returns a cached resolved table or nil: copy before editing. After changing `bgNPC.cfg.actors`, call `Config.ClearCache`; existing actors keep their own copies.
- `States.Register(name, group, callbacks)` registers behavior callbacks in each realm where executed. Execute AI callbacks on the server.
- `Points` wraps the active navigation provider. Its useful graph/path data is server-side; use the navigation editor's synchronization for client route editing.
- `Statistics.Get` returns a count for a type, or a table without a type; `GetSum` returns the total. Client data arrives via network events.
- `Modules.Get(name)` may return nil; availability depends on realm and load stage. A shared accessor does not make a server module available on the client.
