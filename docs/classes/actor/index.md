# Actor API

An actor wraps an NPC or NextBot entity. Get an existing actor with `bgNPC.Actors.GetFirst()` or the list with `bgNPC.Actors.GetAll()`. There may be none yet: check the actor before calling methods and check `GetNPC()` with `IsValid`.

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
- [GetLastReaction](functions/GetLastReaction.md)
- [GetName](functions/GetName.md)
- [GetNPC](functions/GetNPC.md)
- [GetRandomState](functions/GetRandomState.md)
- [IsAlive](functions/IsAlive.md)
- [IsStateDelay](functions/IsStateDelay.md)
- [RandomState](functions/RandomState.md)
- [ResetStateDelay](functions/ResetStateDelay.md)
- [SetName](functions/SetName.md)
- [SetReaction](functions/SetReaction.md)
- [SetStateDelay](functions/SetStateDelay.md)
- [SyncFunction](functions/SyncFunction.md)
