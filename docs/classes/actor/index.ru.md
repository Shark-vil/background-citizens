# API актора

Актор — оболочка над сущностью NPC или NextBot. Получайте существующего через `bgNPC.Actors.GetFirst()` или список через `bgNPC.Actors.GetAll()`. Акторов может ещё не быть: проверяйте объект до вызова метода, а результат `GetNPC()` — через `IsValid`.

При посадке и выходе из машины DV объект актора и UID сохраняются. `GetNPC()` меняется: исходный NPC/NextBot удаляется, в салоне его представляет anim-сущность DV, после выхода создаётся новое тело. Получайте сущность заново после перехода; данные стороннего аддона переносите через `BGN_ActorEntityChanged(actor, old, new)`.

Примеры: [практические рецепты](../../examples.md). Низкоуровневый [Instance](Instance.md) связывает сущность с актором; не вызывайте его повторно для уже зарегистрированного NPC.

## Методы

Ниже — существующий английский справочник. Он описывает также совместимые старые методы; точные сигнатуры сверяйте с `lua/background_npcs_core/actor/components/`. Пустые страницы в указатель не включены.

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
