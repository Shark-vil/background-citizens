# Параметры актора

Конфигурации: `lua/background_npcs_core/config/actors/`. [Пример полного модуля](Creating-Custom-NPCs.md), [изменение существующего](Modification-of-Existing-NPCs.md).

| Поле | Тип | Назначение |
| --- | --- | --- |
| `enabled` | boolean | Включён по умолчанию |
| `class` | string / table | Класс сущности или список классов; обязателен для `SetActor` |
| `name` | string | Название в меню |
| `inherit` | string | ID актора, из которого берутся отсутствующие поля |
| `fullness` | number | Доля общего лимита, 0–100; для фиксированного `limit` поле должно отсутствовать, в том числе у родителя |
| `limit` | number | Фиксированный лимит вместо процентного заполнения |
| `team` | table | Команды: например `residents`, `police`, `bandits`, `zombies` |
| `health` | number / table | Здоровье или диапазон `{ min, max }` |
| `weapons` | table | Классы оружия для выбора |
| `getting_weapon_chance` | number / false | Шанс оружия; `false` — всегда |
| `weapon_skill` | enum | `WEAPON_PROFICIENCY_*`, влияет и на NextBot |
| `brain` | string | `fsm` или `goap` при автоматическом выборе мозга |
| `models` | table | Пути моделей `.mdl`, которые должны быть установлены |
| `default_models` | boolean | Использовать стандартные модели |
| `random_skin`, `random_bodygroups` | boolean | Случайные скины и группы тела |
| `at_random` | table | Относительные веса спокойных состояний |
| `at_damage`, `at_protect` | table | Веса реакций на урон себе и союзнику |
| `disable_states` | boolean | `true` отключает управление состояниями Background NPCs |
| `replics` | table | Привязки реплик к `state_names` и `state_groups` |
| `respawn_delay` | number | Задержка после смерти, секунды. Каждая смерть типа ставит одно отложенное появление в очередь. Наследуется через `inherit`; потомок отключает её значением `0` (не `false`) |
| `wanted_level` | number | Уровень появления при включённой системе розыска |
| `money` | number / table | Сумма или диапазон; нужна интеграция денежной системы |
| `vehicles` | table | Классы транспорта, нужны Decent Vehicle и модели |
| `max_vehicle` | number | Лимит машин типа |
| `vehicle_group` | string | Группа транспорта |
| `vehicle_multiply_speed` | table | Множитель скорости по группе состояния, например `{ danger = 4 }` |
| `enter_to_exist_vehicle_chance` | number | Шанс сесть в существующую машину |
| `vehicles_random_color`, `vehicles_random_skin`, `vehicles_random_bodygroups` | boolean | Случайный внешний вид машины |
| `vehicles_strict_color_chance` | number | Шанс приглушённого случайного цвета |
| `relationship` | table | Отношения к `@player`, `@actor`, `@team`, `@npc` через `D_HT`, `D_LI`, `D_NU` |
| `validator` | function | `function(self, npc_type)`: `false` отменяет создание |
| `bsmod_damage_animation_disable` | boolean | Запрет анимаций BSmod |

`at_random_range`, `at_damage_range`, `at_protect_range` устарели и не используются. Для весов `{ walk = 80, idle = 20 }` прогулка выбирается чаще ожидания; веса не обязаны суммироваться до 100.

При `EditActor` таблицы объединяются: для удаления старых элементов заменяйте поле прямым присваиванием. Установленные в меню значения могут отличаться от исходных значений конфигурации.

## Современные поля поведения и банд

Конфиги разрешаются через `bgNPC.Config.GetActor`; результат кешируется, актору передаётся копия. Новые значения не меняют существующих акторов. Поля транспорта/мозга действуют на сервере, определения типов должны быть доступны в обоих окружениях.

| Поле | Значение | Назначение |
|---|---|---|
| `brain` | `fsm / goap` | Мозг при bgn_brain=auto; принудительная cvar имеет приоритет. |
| `carry_items` | `false / table` | `{ chance = 5, items = { 'ration', 'suitcase', 'newspaper' }, drop_lifetime = 30 }`: редкие предметы у невооружённых акторов; добавляет чекбокс типа. См. [правила переноски](Modification-of-Existing-NPCs.md). |
| `goap_set` | `police / gangster / citizen` | Набор целей GOAP; иначе определяется по команде. |
| `gang` | `string` | Идентификатор банды; учитывается союзами, составом боя и групповой ходьбой. |
| `heavy_chance` | `35` | Процент тяжёлых участников для штатных банд. |
| `light_weapons` | `table` | Классы оружия лёгких участников. |
| `heavy_weapons` | `table` | Классы оружия тяжёлых участников. |
| `mechanics` | `table` | Флаги подсистем актора; см. ниже. |

Штатные флаги `mechanics` по умолчанию включены: `movement_controller`, `use_vehicle`, `call_for_help`, `fear`, `fear_scream`, `enemies_controller`, `targets_controller`, `states_controller`, `animator_controller`, `enhanced_npc_ignore`, `inpc_ignore`.

Ограничения боя, значения cvars и модели: [банды](../systems/gangs.md). Источники — `actor/sh_actor.lua`, `config/actors/sh_gangs.lua`, `brain/sv_brain.lua`.
