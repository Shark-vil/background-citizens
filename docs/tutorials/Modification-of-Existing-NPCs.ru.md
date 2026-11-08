# Изменение существующих акторов

Создайте общий файл в `custom_modules/config`, как описано в [создании актора](Creating-Custom-NPCs.md). Для простых полей используйте:

```lua
bgNPC.cfg:EditActor('citizen', { health = 80, random_skin = true })
```

`EditActor` объединяет данные через `table.Merge`, включая вложенные таблицы. Для замены списков моделей, команд или реакций целиком присвойте новую таблицу:

```lua
-- lua/background_npcs_core/custom_modules/config/sh_mytown_citizens.lua
local citizen = bgNPC.cfg.actors['citizen']
citizen.health = 80
citizen.default_models = false
citizen.models = { 'models/Humans/Group01/male_07.mdl' }
citizen.at_random = { walk = 80, idle = 20 }
```

Не используйте `SetActor` для частичного изменения: он заменяет всю конфигурацию. Перезагрузите карту для проверки. Стандартные конфигурации находятся в `lua/background_npcs_core/config/actors/`, например `sh_citizen.lua`.
