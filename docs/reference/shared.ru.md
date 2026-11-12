# Общий API

Загружается в обоих окружениях. На клиенте доступны полученные данные, а не авторитетная симуляция. Проверяйте наличие актора и валидность его сущности.

## Actor

### EnemiesCount

`actor:EnemiesCount()`

Возвращает учтённое количество врагов.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/EnemiesCount.md).

### EqualStateGroup

`actor:EqualStateGroup(group_name)`

Сверяет группу текущего состояния с именем либо списком.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/EqualStateGroup.md).

### GetActiveWeapon

`actor:GetActiveWeapon()`

Возвращает сущность оружия либо NULL; у визуальной модели пассажира активного оружия может не быть.
Паёк, чемодан/кейс и газета возвращают NULL через API актора; сама движковая сущность может по-прежнему возвращать их.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/GetActiveWeapon.md).

### GetAngles

`actor:GetAngles()`

Возвращает углы текущей сущности либо Angle(0, 0, 0).

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetClass

`actor:GetClass()`

Возвращает исходный класс персонажа, который может отличаться от текущей визуальной сущности.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetClass.md).

### GetData

`actor:GetData()`

Возвращает изменяемую копию конфига конкретного актора. Глобальные правки конфигурации не обновляют существующего актора.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetData.md).

### GetEnemy

`actor:GetEnemy()`

Возвращает ближайшего валидного врага либо NULL; вызывает GetNearEnemy.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/GetEnemy.md).

### GetFirstEnemy

`actor:GetFirstEnemy()`

Возвращает первого валидного врага либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/GetFirstEnemy.md).

### GetFirstTarget

`actor:GetFirstTarget()`

Возвращает первую цель либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/GetFirstTarget.md).

### GetGender

`actor:GetGender()`

Возвращает сохранённый пол либо unknown.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetGender.md).

### GetGenderByModel

`actor:GetGenderByModel()`

Определяет пол по модели без аргументов; при посадке использует сохранённую модель. Возвращает female, male либо unknown.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetGenderByModel.md).

### GetHealth

`actor:GetHealth()`

Эквивалент Health(); безопаснее предположения о наличии GetNPC():Health.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetHealth.md).

### GetLastEnemy

`actor:GetLastEnemy()`

Возвращает последнего валидного врага либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/GetLastEnemy.md).

### GetLastReaction

`actor:GetLastReaction()`

Возвращает последнюю сохранённую реакцию.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetLastReaction.md).

### GetLastTarget

`actor:GetLastTarget()`

Возвращает последнюю цель либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/GetLastTarget.md).

### GetMaxHealth

`actor:GetMaxHealth()`

Возвращает максимум здоровья текущей сущности, иначе сохранённый максимум пассажира либо 0.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetMaxHealth.md).

### GetNPC

`actor:GetNPC()`

Возвращает текущую сущность, возможен NULL при замене тела. В машине это визуальная сущность DV. После BGN_ActorEntityChanged получайте её заново и проверяйте IsValid.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetNPC.md).

### GetName

`actor:GetName()`

Возвращает сохранённое отображаемое имя.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetName.md).

### GetNearEnemy

`actor:GetNearEnemy()`

Возвращает ближайшего валидного врага либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/GetNearEnemy.md).

### GetNearTarget

`actor:GetNearTarget()`

Возвращает ближайшую валидную цель либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/GetNearTarget.md).

### GetOldState

`actor:GetOldState()`

Возвращает имя предыдущего состояния.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetOldState.md).

### GetOldStateData

`actor:GetOldStateData()`

Возвращает данные предыдущего состояния; клиент не получает полную серверную таблицу.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetOldStateData.md).

### GetPos

`actor:GetPos()`

Возвращает позицию текущей сущности либо Vector(0, 0, 0).

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetRelationship

`actor:GetRelationship(value, default)`

Возвращает отношение из конфига к сущности/актору, иначе default.

Исходник: `lua/background_npcs_core/actor/components/sh_team.lua`.

### GetState

`actor:GetState()`

Возвращает имя текущего состояния.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetState.md).

### GetStateData

`actor:GetStateData()`

Возвращает изменяемую таблицу текущего состояния; клиентский снимок содержит только имя состояния.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetStateData.md).

### GetStateGroupName

`actor:GetStateGroupName()`

Возвращает зарегистрированную группу текущего состояния.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetStateGroupName.md).

### GetTarget

`actor:GetTarget(index)`

Возвращает цель по индексу (по умолчанию 1) либо NULL.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/GetTarget.md).

### GetType

`actor:GetType()`

Возвращает ID конфигурации актора, например citizen.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/GetType.md).

### HasActiveWeapon

`actor:HasActiveWeapon()`

Проверяет валидность результата GetActiveWeapon.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### HasEnemy

`actor:HasEnemy(ent)`

Проверяет наличие ent в списке врагов.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/HasEnemy.md).

### HasNoEnemies

`actor:HasNoEnemies()`

Возвращает true, если врагов нет.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

### HasNoTargets

`actor:HasNoTargets()`

Возвращает true, если целей нет.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

### HasSequence

`actor:HasSequence(sequence_name)`

Проверяет сохранённое имя последовательности без учёта регистра.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/HasSequence.md).

### HasState

`actor:HasState(state)`

Проверяет имя состояния либо список имён; возвращает boolean.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/HasState.md).

### HasStateGroup

`actor:HasStateGroup(state_name, group_name)`

Проверяет группу заданного состояния по имени либо списку.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/HasStateGroup.md).

### HasTarget

`actor:HasTarget(ent)`

Проверяет наличие ent в списке целей.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/HasTarget.md).

### HasTeam

`actor:HasTeam(value)`

Принимает имя/список команд, сущность либо актора. Для банд действуют особые правила: общий bandits не означает союз.

Исходник: `lua/background_npcs_core/actor/components/sh_team.lua`.

[Страница метода](../classes/actor/functions/HasTeam.md).

### Health

`actor:Health()`

Возвращает здоровье текущей сущности, если её метод Health доступен, иначе сохранённое здоровье пассажира либо 0. Работает в обоих окружениях.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/Health.md).

### InVehicle

`actor:InVehicle()`

Сервер проверяет провайдер, клиент читает bgn_vehicle_entered текущей сущности.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Страница метода](../classes/actor/functions/InVehicle.md).

### IsAlive

`actor:IsAlive()`

Проверяет жизнь персонажа; на сервере мёртвый актор также снимается с регистрации.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/IsAlive.md).

### IsAnimationPlayed

`actor:IsAnimationPlayed()`

Проверяет флаг анимации актора и состояние Animator.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/IsAnimationPlayed.md).

### IsLoopSequence

`actor:IsLoopSequence()`

Возвращает флаг зацикленности анимации.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/IsLoopSequence.md).

### IsMeleeWeapon

`actor:IsMeleeWeapon()`

Проверяет активный/назначенный класс по списку ближнего оружия; без класса — false.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/IsMeleeWeapon.md).

### IsNPC

`actor:IsNPC()`

Проверяет, является ли текущая сущность движковым NPC.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### IsNextBot

`actor:IsNextBot()`

Проверяет, является ли текущая сущность NextBot.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### IsStateLock

`actor:IsStateLock()`

Возвращает флаг блокировки.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/IsStateLock.md).

### IsValid

`actor:IsValid()`

Проверяет текущую сущность; не равнозначно проверке жизни.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/IsValid.md).

### IsValidSequence

`actor:IsValidSequence(sequence_name)`

Проверяет наличие последовательности у модели; в машине — false.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/IsValidSequence.md).

### TargetsCount

`actor:TargetsCount()`

Возвращает учтённое количество целей.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/TargetsCount.md).

## actors

Исходник: `lua/background_npcs_core/api/sh_actors.lua`.

| Сигнатура |
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

Исходник: `lua/background_npcs_core/api/sh_config.lua`.

| Сигнатура |
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

Исходник: `lua/background_npcs_core/api/sh_states.lua`.

| Сигнатура |
|---|
| `bgNPC.States.Register(state_name, group_name, callbacks)` |
| `bgNPC.States.Exists(state_name)` |
| `bgNPC.States.GetGroup(state_name)` |
| `bgNPC.States.Call(state_name, func_name, ...)` |
| `bgNPC.States.HasAction(state_name, func_name)` |

## modes

Исходник: `lua/background_npcs_core/api/sh_modes.lua`.

| Сигнатура |
|---|
| `bgNPC.Modes.IsPeaceful()` |
| `bgNPC.Modes.IsFriend()` |
| `bgNPC.Modes.IsAggressive()` |

## vision

Исходник: `lua/background_npcs_core/api/sh_vision.lua`.

| Сигнатура |
|---|
| `bgNPC.Vision.HasLineOfSight(watcher, ent, channel)` |
| `bgNPC.Vision.NPCCanSeePos(ent, pos, fov)` |
| `bgNPC.Vision.PlayerCanSeePos(ply, pos, radius)` |
| `bgNPC.Vision.AnyActorSees(ent, exclude)` |
| `bgNPC.Vision.ActorsThatSee(ent)` |

`channel` — необязательная метка отладки (по умолчанию `los`). Она не меняет условие LOS и результаты boolean/попавшая сущность. SERVER записывает существующий результат только для актёра с подпиской и слоем зрения; CLIENT не передаёт телеметрию зрения.

## statistics

Исходник: `lua/background_npcs_core/api/sh_statistics.lua`.

| Сигнатура |
|---|
| `bgNPC.Statistics.Get(attacker, actor_type)` |
| `bgNPC.Statistics.GetSum(attacker)` |

## assert

Исходник: `lua/background_npcs_core/api/sh_assert.lua`.

| Сигнатура |
|---|
| `bgNPC.Assert.Arg(index, value, spec, func_name)` |
| `bgNPC.Assert.Field(owner_name, field_name, value, spec)` |
| `bgNPC.Assert.True(condition, message, ...)` |
| `bgNPC.Assert.NonEmptyString(index, value, func_name)` |
| `bgNPC.Assert.Is(value, spec)` |
| `bgNPC.Assert.RegisterType(type_name, checker)` |

## core

Исходник: `lua/background_npcs_core/api/sh_core.lua`.

| Сигнатура |
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

Исходник: `lua/background_npcs_core/api/sh_points.lua`.

| Сигнатура |
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

## Контракты данных

- `Actors.Get`, `GetByUid`, `GetFirst` и поиск ближайшего могут вернуть nil. Общие списки и списки типов/NPC — внутренние: не изменяйте их.
- `Config.GetActor` возвращает кешированную таблицу либо nil; перед правкой копируйте. После изменения `bgNPC.cfg.actors` вызывайте `Config.ClearCache`. Существующие акторы хранят свои копии.
- `States.Register(name, group, callbacks)` регистрирует callbacks в том окружении, где выполнен вызов; игровой ИИ выполняйте на сервере.
- `Points` — фасад активного провайдера. Полезный граф/пути принадлежат серверу; для редактора на клиенте есть собственная синхронизация.
- `Statistics.Get` возвращает число по типу либо таблицу без типа; `GetSum` — сумму. Клиент получает сетевые события.
- `Modules.Get(name)` может вернуть nil в зависимости от окружения/стадии загрузки. Общий accessor не делает серверный модуль доступным клиенту.
