# Навигация

Сервер выбирает один провайдер: сохранённый граф аддона (`data/background_npcs/graph/<map>.dat`), затем NavMesh карты, затем HL2 nodegraph (`maps/graphs/<map>.ain`). Если данных нет, используется пустой собственный граф с генерацией во время работы. Старые маршруты автоматически конвертируются при загрузке. Аддон не запускает движковую генерацию NavMesh.

| Команда | Назначение |
| --- | --- |
| `bgn_nav_info` | Провайдер и число точек |
| `bgn_nav_provider auto` | Автоматический выбор; также доступны `navmesh`, `nodegraph`, `custom` |
| `bgn_nav_reload` | Перезагрузить данные |
| `bgn_nav_generate around 1500` | Сгенерировать точки вокруг игрока |
| `bgn_nav_generate` | Генерация по всей карте от точек появления и игроков |
| `bgn_nav_generate stop` | Остановить генерацию |
| `bgn_compile` | Упаковать маршруты, сиденья и точки DV в Lua для распространения |

Команды выполняются на сервере с правами администратора. Лимит генератора `bgn_nav_generator_max_nodes` — 15000. Инструмент Point editor создаёт, связывает и удаляет точки собственного графа; сохраняйте маршрут кнопкой панели. Path finder показывает путь между точками.

## Двери и машины

`bgn_npc_open_doors 1` разрешает открывать двери. Запертые двери по умолчанию запрещены (`bgn_npc_open_locked_doors 0`); при включении актор отпирает дверь и после закрытия через 10 секунд запирает её снова. Настройки находятся в общем разделе меню.

Полицейские машины при погоне и скорая на вызове используют маршруты Decent Vehicle, сирену и игнорируют светофоры. Пешеходный граф не заменяет автомобильный.

## API сервера

```lua
local info = bgNPC.Nav.GetInfo() -- provider, points, links, source
print(info.provider, info.points)
local points = bgNPC.Points.GetInRadius(Vector(0, 0, 0), 1000)
for _, point in ipairs(points) do
    print(point:GetPos())
end
```

События: `BGN_NavProviderChanged(provider)`, `BGN_NavGeneratorFinished(graph, added_count)` на сервере; `BGN_NavEditorGraphLoaded(graph)` на клиенте.
