# Серверный API

Изменяйте игровой мир на SERVER. Многие методы объявлены в sh_-файлах для совместимости, но требуют серверного тела, мозга, провайдера или игрового модуля.

`bgNPC.Actor.New(...)` — конструктор класса без проверок фабрики. Для расширений используйте `bgNPC.Actor.Create(...)`. `actor:StopStaticSequence()` — алиас `ResetSequence()`.

## Actor

### AddEnemy

`actor:AddEnemy(ent, reaction, always_visible)`

Добавляет сущность/актора с необязательными reaction и always_visible; хуки и команды могут запретить добавление.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/AddEnemy.md).

### AddTarget

`actor:AddTarget(ent)`

Добавляет валидную цель-сущность без дублей; требуется targets_controller.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/AddTarget.md).

### AddTeam

`actor:AddTeam(team_name)`

Добавляет непустое имя команды без дублей.

Исходник: `lua/background_npcs_core/actor/components/sh_team.lua`.

### AvoidDVVehicle

`actor:AvoidDVVehicle(goal)`

Внутреннее обновление обхода транспорта; возвращает активность обхода.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### CallForHelp

`actor:CallForHelp(enemy)`

Просит живых союзников в радиусе 1000 единиц с LOS к зовущему отреагировать на врага. Видеть врага необязательно; FOV не проверяется. Нужны механика `call_for_help`, допустимый враг и живой зовущий. `BGN_PreCallForHelp` отменяет вызов; защита ареста, запреты назначения врагов и пауза защиты сохраняются.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/CallForHelp.md).

### CallStateAction

`actor:CallStateAction(state_name, func_name, ...)`

Вызывает callback с актором и дополнительными аргументами; nil state_name означает текущее состояние.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/CallStateAction.md).

### CheckMoveUpdate

`actor:CheckMoveUpdate(tag, time)`

Ограничивает частоту по тегу: первый вызов false, следующие true после истечения интервала.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### ClearSchedule

`actor:ClearSchedule()`

Устаревший API расписаний тела; предпочитайте WalkToPos/StopWalk.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/ClearSchedule.md).

### Create

`bgNPC.Actor.Create(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)`

Проверяет сущность и ID типа, затем создаёт актора и регистрирует его; возвращает актор либо nil. Используйте bgNPC.Actor.Create(npc, npc_type). Дополнительные аргументы задают UID и отключают начальную синхронизацию/авторегистрацию. Не привязывайте сущность дважды.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### CreateFakePlayerMethodsForNPC

`actor:CreateFakePlayerMethodsForNPC()`

Внутренний адаптер совместимости NPC; не способ создания актора.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### DropToFloor

`actor:DropToFloor()`

Передаёт размещение на полу телу либо валидной сущности.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### EnemiesRecalculate

`actor:EnemiesRecalculate()`

Обновляет счётчики, удаляет мёртвых/забытых врагов и назначает ближайшего телу; требуется валидное тело.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/EnemiesRecalculate.md).

### EnterVehicle

`actor:EnterVehicle(vehicle, animate)`

Принимает валидную сущность машины, сам находит/создаёт её провайдер. Посадка проверяется повторно после задержки 0,5 с, синхронного результата успеха нет. С `animate` актор сначала останавливается и поворачивается к машине (без анимации); метод возвращает задержку в секундах. Actor/UID сохраняются, сущность заменяется.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Страница метода](../classes/actor/functions/EnterVehicle.md).

### ExitVehicle

`actor:ExitVehicle(forced)`

Возвращает true при завершённом выходе. Заблокированный выход сохраняет посадку. Воссоздаёт сохранённое тело NPC/NextBot.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Страница метода](../classes/actor/functions/ExitVehicle.md).

### Fear

`actor:Fear()`

Выполняет механику страха, если она включена.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### FearScream

`actor:FearScream()`

Проигрывает голос страха, если это разрешено.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/FearScream.md).

### FoldWeapon

`actor:FoldWeapon()`

Удаляет активное оружие, если не установлен disable_fold_weapon.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/FoldWeapon.md).

### GetActorWeapon

`actor:GetActorWeapon()`

Возвращает назначенный класс оружия, а не сущность. Это назначение не передаётся обычным клиентским снимком.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/GetActorWeapon.md).

### GetBody

`actor:GetBody()`

Возвращает серверный адаптер тела либо nil; при посадке/выходе адаптер заменяется.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetBrain

`actor:GetBrain()`

Возвращает серверный мозг либо nil.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### GetClosestPointInRadius

`actor:GetClosestPointInRadius(radius)`

Возвращает ближайшую точку навигации вокруг актора либо nil.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/GetClosestPointInRadius.md).

### GetClosestPointToPoint

`actor:GetClosestPointToPoint(pos, radius)`

Возвращает ближайшую к pos точку навигации в радиусе либо nil.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/GetClosestPointToPoint.md).

### GetDistantPointInRadius

`actor:GetDistantPointInRadius(radius)`

Возвращает наиболее далёкую точку навигации вокруг актора либо nil.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/GetDistantPointInRadius.md).

### GetDistantPointToPoint

`actor:GetDistantPointToPoint(pos, radius)`

Возвращает наиболее далёкую от pos точку навигации в радиусе либо nil.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/GetDistantPointToPoint.md).

### GetRandomState

`actor:GetRandomState()`

Возвращает случайное имя по весам at_random либо none при пустых/нулевых весах.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetRandomState.md).

### GetReactionForDamage

`actor:GetReactionForDamage(enemy)`

Выбирает реакцию мозгом либо по весам at_damage; разыскиваемые отступают вместо defense.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetReactionForDamage.md).

### GetReactionForProtect

`actor:GetReactionForProtect(enemy)`

Выбирает реакцию at_protect с проверкой паузы и участия жителей.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/GetReactionForProtect.md).

### GetVehicle

`actor:GetVehicle()`

Возвращает шасси либо nil; требуется серверный провайдер. Клиент проверяет посадку через InVehicle.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Страница метода](../classes/actor/functions/GetVehicle.md).

### GetVehicleAI

`actor:GetVehicleAI()`

Возвращает контроллер DV либо nil; требуется серверный провайдер.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

[Страница метода](../classes/actor/functions/GetVehicleAI.md).

### GetVehicleGroup

`actor:GetVehicleGroup()`

Возвращает первую настроенную группу либо police/taxi/residents по роли.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

### GetWalkPos

`actor:GetWalkPos()`

Возвращает текущую позицию назначения либо nil.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### GetWalkTarget

`actor:GetWalkTarget()`

Возвращает сущность следования (возможен NULL).

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### GiveWeapon

`actor:GiveWeapon(weapon_class)`

Меняет назначенный класс, не экипирует немедленно; nil очищает назначение.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

### Init

`actor:Init(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)`

Внутренний конструктор. Используйте bgNPC.Actor.Create с проверками входных данных.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### IsCivilian

`actor:IsCivilian()`

Возвращает true для residents, не входящих в police.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

### IsExecutingCombatSchedule

`actor:IsExecutingCombatSchedule()`

Проверяет, занято ли серверное тело стрельбой/перезарядкой.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### IsSequenceFinished

`actor:IsSequenceFinished()`

Проверяет завершение анимации с учётом длительности цикла.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/IsSequenceFinished.md).

### IsSequenceLoopFinished

`actor:IsSequenceLoopFinished()`

Проверяет срок цикла; активный бесконечный цикл не завершён.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/IsSequenceLoopFinished.md).

### IsStateDelay

`actor:IsStateDelay()`

Проверяет локальный state_delay; этот срок не передаётся обычным клиентским снимком. Используйте на сервере.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/IsStateDelay.md).

### IsStayingOut

`actor:IsStayingOut()`

Проверяет срок воздержания от боя.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

### IsWanted

`actor:IsWanted()`

Проверяет текущую сущность в серверном модуле розыска.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

### PlayNextStaticSequence

`actor:PlayNextStaticSequence()`

Забирает анимацию из очереди; возвращает, начата ли её обработка.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/PlayNextStaticSequence.md).

### PlayStaticSequence

`actor:PlayStaticSequence(sequence_name, loop, loop_time, action)`

Возвращает boolean; loop_time nil/0 задаёт бесконечный цикл. Требует тело и доступную последовательность. action может вернуть true и запретить остановку.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/PlayStaticSequence.md).

### PoliceFights

`actor:PoliceFights(enemy)`

Проверяет, сражается ли полиция поблизости с enemy для ограничения участия жителей.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

### PrepareWeapon

`actor:PrepareWeapon(weapon_class, switching)`

Экипирует/выбирает заданный или назначенный класс через bgNPC.Combat.EquipActor.

Исходник: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Страница метода](../classes/actor/functions/PrepareWeapon.md).

### RandomState

`actor:RandomState()`

Выбирает и применяет состояние по весам at_random, если PreRandomState не отменил выбор. Возвращает итоговое имя состояния.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/RandomState.md).

### RecalculationTargets

`actor:RecalculationTargets()`

Удаляет невалидные цели. Именно это имя реализовано; TargetsRecalculate отсутствует.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/RecalculationTargets.md).

### Remove

`actor:Remove()`

Снимает регистрацию и удаляет текущую сущность.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### RemoveActor

`actor:RemoveActor()`

Однократно снимает регистрацию, останавливает мозг, освобождает провайдер транспорта. Саму сущность не удаляет.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### RemoveAllEnemies

`actor:RemoveAllEnemies()`

Вызывает хуки удаления врагов, затем очищает оставшееся хранилище.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/RemoveAllEnemies.md).

### RemoveAllTargets

`actor:RemoveAllTargets()`

Вызывает хуки удаления целей, затем принудительно очищает остаток.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/RemoveAllTargets.md).

### RemoveEnemy

`actor:RemoveEnemy(ent, index)`

Удаляет по сущности либо индексу (индекс приоритетен); хук может запретить. Возвращает оставшееся количество.

Исходник: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Страница метода](../classes/actor/functions/RemoveEnemy.md).

### RemoveTarget

`actor:RemoveTarget(ent, index)`

Удаляет цель по сущности либо индексу (индекс приоритетен); возвращает число оставшихся.

Исходник: `lua/background_npcs_core/actor/components/sh_targets.lua`.

[Страница метода](../classes/actor/functions/RemoveTarget.md).

### ResetSequence

`actor:ResetSequence()`

Останавливает статическую анимацию, если callback не запретил и не запустил следующую.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/ResetSequence.md).

### ResetStateDelay

`actor:ResetStateDelay()`

Сбрасывает задержку перехода состояния.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/ResetStateDelay.md).

### Say

`actor:Say(say_text, say_time, voice_sound, animation_sequence)`

Рассылает текст (по умолчанию 5 с), при необходимости звук и анимацию.

Исходник: `lua/background_npcs_core/actor/components/sh_speech.lua`.

[Страница метода](../classes/actor/functions/Say.md).

### SayReplic

`actor:SayReplic(replic_id, replic_index, say_time, voice_sound, animation_sequence)`

Рассылает ID/индекс фразы для клиентской локализации; отсутствующая фраза игнорируется.

Исходник: `lua/background_npcs_core/actor/components/sh_speech.lua`.

### SetGender

`actor:SetGender(gender_name)`

Задаёт строку пола; nil сбрасывает в unknown. Синхронизируется сервером.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/SetGender.md).

### SetName

`actor:SetName(name)`

Меняет имя строкой; nil оставляет прежнее. Обычная серверная синхронизация передаёт имя клиентам.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/SetName.md).

### SetNextSequence

`actor:SetNextSequence(sequence_name, loop, loop_time, action)`

Ставит одну последовательность в очередь с параметрами цикла и callback.

Исходник: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Страница метода](../classes/actor/functions/SetNextSequence.md).

### SetReaction

`actor:SetReaction(reaction)`

Сохраняет строку реакции либо nil; не выполняет реакцию.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/SetReaction.md).

### SetSchedule

`actor:SetSchedule(schedule)`

Устаревшие числовые schedule движка; NextBot поддерживает только часть.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/SetSchedule.md).

### SetState

`actor:SetState(state, data, forced)`

Возвращает новую таблицу {state, data} либо nil при отказе. nil означает none. forced обходит обычные блокировки/задержки/validator, но проверки механики/жизни и предварительные хуки всё ещё могут отказать.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/SetState.md).

### SetStateDelay

`actor:SetStateDelay(time)`

Задерживает обычные переходы на time секунд от CurTime().

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/SetStateDelay.md).

### SetTeam

`actor:SetTeam(team_data)`

Заменяет список команд конкретного актора; nil очищает его.

Исходник: `lua/background_npcs_core/actor/components/sh_team.lua`.

### SetWalkType

`actor:SetWalkType(move_type)`

Принимает walk, run, числовой schedule либо nil (walk).

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/SetWalkType.md).

### ShouldExitVehicle

`actor:ShouldExitVehicle()`

Проверяет серверные условия выхода, не выполняя выход.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

### StateLock

`actor:StateLock(lock)`

Устанавливает блокировку перехода; nil/false снимает её.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/StateLock.md).

### StayOutOfFight

`actor:StayOutOfFight(time)`

Ограничивает участие через defense на time секунд (по умолчанию 15), сбрасывает план GOAP.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

### StopWalk

`actor:StopWalk()`

Очищает цели, преследование и обход DV, сбрасывает тип ходьбы.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/StopWalk.md).

### SyncFunction

`actor:SyncFunction(name, ply, data)`

Серверная обёртка совместимости: bgNPC.Net.Send(name, ply, self.uid, data). Приём через bgNPC.Net.Receive; SNet не нужен.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

[Страница метода](../classes/actor/functions/SyncFunction.md).

### TakeVehicleDamage

`actor:TakeVehicleDamage(amount, attacker, inflictor)`

Применяет урон пассажиру через реакции и здоровье персонажа; смерть вызывает хуки и удаляет актора.

Исходник: `lua/background_npcs_core/actor/components/sh_vehicle.lua`.

### Think

`actor:Think()`

Устаревший вход: мозг обновляет общий сервис акторов. Не добавляйте второй Think-цикл.

Исходник: `lua/background_npcs_core/actor/sh_actor.lua`.

### UpdateMovement

`actor:UpdateMovement()`

Внутренний сервис следования пути; не добавляйте второй цикл обновления.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/UpdateMovement.md).

### UpdateStateData

`actor:UpdateStateData(data)`

Заменяет таблицу данных состояния целиком, не объединяет её.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Страница метода](../classes/actor/functions/UpdateStateData.md).

### Voice

`actor:Voice(voice_id, fallback)`

Рассылает событие голоса; каждый клиент выбирает язык/запасной звук. Боевые реплики ограничены по частоте на актора.

Исходник: `lua/background_npcs_core/actor/components/sh_speech.lua`.

### VoiceSay

`actor:VoiceSay(sound_path, sound_level, pitch_percent, volume, channel, sound_flags, dsp)`

Проигрывает явный путь звука на сущности с параметрами EmitSound по умолчанию.

Исходник: `lua/background_npcs_core/actor/components/sh_speech.lua`.

[Страница метода](../classes/actor/functions/VoiceSay.md).

### WalkDestinationExists

`actor:WalkDestinationExists()`

Проверяет наличие позиции либо валидной цели следования.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

### WalkToPos

`actor:WalkToPos(pos, move_type, path_type)`

Начинает движение к Vector либо node:GetPos(); nil останавливает. Нужен доступный путь; завершение сообщает BGN_ActorFinishedWalk.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/WalkToPos.md).

### WalkToTarget

`actor:WalkToTarget(target, move_type, path_type)`

Следует за сущностью с перестроением пути; nil/невалидная цель останавливает.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/WalkToTarget.md).

### Walking

`actor:Walking()`

Сообщает о движении тела; адаптер существует только на сервере.

Исходник: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Страница метода](../classes/actor/functions/Walking.md).

## Пространства имён и сервисы

| API | Контракт / исходник |
|---|---|
| `bgNPC:SpawnActor(npc_type, desiredPosition, enableSpawnEffect, require_hidden)` | Создаёт актора по типу и позиции; `spawner/sv_spawner.lua`. Проверяйте результат. |
| `bgNPC.Statistics.AddKill(attacker, actor)` | Учитывает и синхронизирует убийство. |
| `bgNPC.Statistics.Reset(attacker)`, `ResetAll()` | Очищает и синхронизирует статистику. |
| `bgNPC.Actors.Rebind(actor, npc)` | Внутренняя замена тела, реестров и ссылок с BGN_ActorEntityChanged. Используйте штатную посадку/выход. |
| `bgNPC.Combat` | Оружие/навык, бой, определение нападающего в машине: `api/sv_combat.lua`. |
| `bgNPC.Nav` | Провайдеры/загрузка/пути: `nav/sv_nav.lua`, [навигация](../systems/navigation.md). |
| `bgNPC.GOAP` | Действия/сенсоры планировщика: [мозги](../systems/brains.md). |
| `bgNPC.Tasks` | Кооперативные задачи yield/wait/budget; `core/sh_tasks.lua`. У каждого окружения собственный планировщик. |
| `bgNPC.Modules.Get('wanted')` | Розыск: [контракт и события](../systems/wanted.md). |

`bgNPC.Combat.CanPoliceUseStunstick(officer, suspect)` возвращает SERVER-допустимость станстика по розыску, убийствам, личной памяти полицейского и тому, ранил ли кто-то из его врагов кого-либо с расстояния больше 500 единиц. `bgNPC.Combat.ResetPoliceThreat(suspect)` очищает признаки/счётчики убийств и записи пострадавших; применять для завершённого сброса, не при первоначальном объявлении розыска. `BGN_PostVehicleDamage(actor, attacker, amount)` вызывается на SERVER после изменения виртуального здоровья в машине, до обработки смерти.

`bgNPC.Combat.CanWitness(actor, attacker, check_view)` проверяет живого наблюдателя, допустимого нападающего, дистанцию до 2500 и LOS к нападающему; для нападающего ACTOR также нужен FOV. `check_view = true` требует FOV для любого нападающего. Возвращает логическое значение видимости и может вернуть сущность попадания LOS вторым значением. `BGN_ConfirmedDamage(attacker, target, amount)` вызывается на SERVER после фактического положительного урона, включая здоровье в машине, после записи инициатора и проверки порогов уже идущего ареста; начало ареста и свидетели обрабатывают это уведомление. Добровольная кулачная драка и игнорируемые нападающие исключены; дружелюбный режим сохраняет существующее переопределение реакций в пользу игрока вместо этого уведомления для конфликтов с игроком. `BGN_PostReactionTakeDamage` остаётся хуком реакции до применения урона и не подтверждает фактический урон. См. [конфликты](../systems/wanted.md#conflict-memory-and-witnesses).

`bgNPC.Combat.IsAttackingEnemy(actor, target, attacker)` возвращает SERVER boolean: цель уже является врагом наблюдателя, а между наблюдателем и нападающим нет вражды по спискам врагов и `D_HT` в любом направлении. Читает настроенные отношения ACTOR, отношения тел (включая NextBot) и доступные методы сущностей `Disposition`. Недопустимые сущности и прямое попадание по наблюдателю возвращают false; отсутствие необязательных методов не означает ненависть. Для этого исключения `ResolveEnemy` возвращает nil до выбора по инициатору, команде или розыску: наблюдатель не вмешивается в это попадание. Предикат не меняет команды, списки врагов или память конфликта.
