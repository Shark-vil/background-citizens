# Создание своего актора

Создайте отдельный каталог аддона `garrysmod/addons/mytown`. Не редактируйте файлы Background NPCs: обновления могут затереть изменения.

Минимальный путь файла: `mytown/lua/background_npcs_core/custom_modules/config/sh_mytown_guard.lua`. Префикс `sh_` загружает файл на сервере и клиентах; `sv_` — только на сервере, `cl_` — только на клиенте. Используйте уникальные имена файлов и ID акторов.

Папки модулей загружаются по порядку: `config` после стандартных конфигураций, `preload` после API и cvar до основных систем, `postload` после основных систем. Для настройки акторов достаточно `config`.

```lua
-- lua/background_npcs_core/custom_modules/config/sh_mytown_guard.lua
bgNPC.cfg:SetActor('mytown_guard', {
    enabled = true,
    class = 'npc_citizen',
    name = 'Town guard',
    limit = 2,
    team = { 'residents' },
    health = 100,
    weapons = { 'weapon_pistol' },
    getting_weapon_chance = false,
    at_random = { walk = 70, idle = 30 },
    at_damage = { defense = 100 },
    at_protect = { defense = 100 },
})
```

`SetActor(id, data)` регистрирует полную конфигурацию. `class` обязателен. Здесь используется фиксированный `limit` без процентного `fullness`. Если добавить `inherit`, отсутствующие поля будут взяты у родителя, включая его `fullness`: учитывайте это при выборе лимита. Проверяйте [параметры](Actor-Config-Settings.md).

Перезапустите игру после создания каталога аддона. После правок Lua перезагрузите карту. Найдите новый тип в меню и проверьте, что он включён и лимит не равен нулю. Для поведения NextBot нужна карта с NavMesh; подробности — [тела и мозги](../systems/brains.md).
