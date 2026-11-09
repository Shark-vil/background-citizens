# Actor API

An actor wraps an NPC or NextBot entity. Get an existing actor with `bgNPC.Actors.GetFirst()` or the list with `bgNPC.Actors.GetAll()`. There may be none yet: check the actor before calling methods and check `GetNPC()` with `IsValid`.

The actor object and UID remain stable when boarding or leaving a DV vehicle. `GetNPC()` changes from the original NPC/NextBot to a DV anim entity and back to a recreated body. Fetch it again after these transitions; integrate body-specific addon state with `BGN_ActorEntityChanged(actor, old, new)`.

See [practical examples](../../examples.md). Low-level [Instance](Instance.md) binds an entity to an actor; do not bind an already registered NPC again.

## Methods

This reference includes legacy compatibility methods. Check exact signatures in `lua/background_npcs_core/actor/components/`. Empty placeholder pages are omitted.

- [AddEnemy](functions/AddEnemy.md)
- [AddTarget](functions/AddTarget.md)
- [CallForHelp](functions/CallForHelp.md)
- [CallStateAction](functions/CallStateAction.md)
- [ClearSchedule](functions/ClearSchedule.md)
- [EnemiesCount](functions/EnemiesCount.md)
- [EnemiesRecalculate](functions/EnemiesRecalculate.md)
- [EnterVehicle](functions/EnterVehicle.md)
- [ExitVehicle](functions/ExitVehicle.md)
- [GetHealth](functions/GetHealth.md)
- [GetMaxHealth](functions/GetMaxHealth.md)
- [GetLastReaction](functions/GetLastReaction.md)
- [GetName](functions/GetName.md)
- [GetNPC](functions/GetNPC.md)
- [GetRandomState](functions/GetRandomState.md)
- [Health](functions/Health.md)
- [IsAlive](functions/IsAlive.md)
- [IsStateDelay](functions/IsStateDelay.md)
- [RandomState](functions/RandomState.md)
- [ResetStateDelay](functions/ResetStateDelay.md)
- [SetName](functions/SetName.md)
- [SetReaction](functions/SetReaction.md)
- [SetStateDelay](functions/SetStateDelay.md)
- [SyncFunction](functions/SyncFunction.md)
