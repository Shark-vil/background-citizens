# Практические примеры

## Меньше нагрузки

В клиентской консоли выполните `bgn_crowd_density low`. Пресет задаёт лимит 25 акторов и отключает призраков (админ меняет серверный лимит; остальные игроки — только своих призраков, и только пока сервер не ведёт фоновую толпу). Для возврата к среднему пресету — `bgn_crowd_density medium` (35 акторов, 40 призраков). Лимиты типов следуют общему лимиту; текущие акторы не обязаны исчезнуть немедленно.

## Русский интерфейс, английские голоса

```text
bgn_cl_ui_language russian
bgn_cl_voice_language english
bgn_cl_voices 1
```

Выполняйте в клиентской консоли. Вернуть выбор по языку игры можно значением `auto` для обеих языковых настроек. Серверный `bgn_module_replics_language`, если не `auto`, задаёт язык фраз для всех.

## Жители с одной моделью и простым поведением

Создайте отдельный аддон по [инструкции](tutorials/Creating-Custom-NPCs.md) и добавьте файл:

```lua
-- lua/background_npcs_core/custom_modules/config/sh_mytown_citizens.lua
local citizen = bgNPC.cfg.actors['citizen']
citizen.health = 80
citizen.default_models = false
citizen.models = { 'models/Humans/Group01/male_07.mdl' }
citizen.at_random = { walk = 80, idle = 20 }
```

Здесь таблицы заменяются целиком. `EditActor` использует `table.Merge`: старые ключи и элементы списков могут сохраниться. После изменения конфигурации перезагрузите карту; для нового каталога аддона перезапустите игру.

## Два вооружённых охранника

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

`class` обязателен для `SetActor`. Эта независимая конфигурация использует фиксированный `limit`; не добавляйте `fullness`, который имеет приоритет над ним. Вес реакции — относительный вес выбора; это не гарантия победы в бою.

## Найти актора и изменить имя

Код для серверного `custom_modules/postload/sv_mytown_inspect.lua`. Команду запускает только администратор или серверная консоль:

```lua
concommand.Add('mytown_inspect', function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local actor = bgNPC.Actors.GetFirst()
    if not actor or not actor:IsValid() then
        print('No actors spawned yet')
        return
    end
    local npc = actor:GetNPC()
    if not IsValid(npc) then return end
    actor:SetName('Town resident')
    print(actor:GetType(), npc:GetPos())
end)
```
