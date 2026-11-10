# Клиентский API

CLIENT отвечает за отображение и полученные снимки состояния. ИИ акторов управляет сервер.

## Actor

### SyncState

`actor:SyncState(state)`

Внутренняя клиентская синхронизация: сохраняет имя без серверных callbacks. Полная таблица данных состояния клиенту не передаётся.

Исходник: `lua/background_npcs_core/actor/components/sh_state.lua`.

## Окно настроек

Исходник: `lua/background_npcs_core/ui/menu/cl_menu.lua`; полный пример — [расширение меню](../systems/menu.md).

| API | Назначение |
|---|---|
| `bgNPC.Menu.AddPage(id, def)` | Регистрирует `{title, order, icon, group, build}`; build получает страницу. |
| `bgNPC.Menu.RemovePage(id)` | Удаляет страницу из реестра. |
| `bgNPC.Menu.Open(page_id)`, `Close()`, `IsOpen()` | Жизненный цикл окна. |
| `bgNPC.Menu.ShowPage(page_id)` | Выбор существующей страницы. |
| `bgNPC.Menu.Text(value)`, `Phrase(key)` | Разрешение локализованных строк. |
| `bgNPC.Menu.IsAdmin()` | Проверка отображения; сервер всё равно проверяет права. |
| `bgNPC.Actors.ReceiveBinding(npc, npc_type, uid, info, generation, class, model)` | Внутренний приёмник привязки: игнорирует старые поколения, сохраняет UID. Не создавайте клиентских акторов независимо. |

Голоса, субтитры, HUD розыска, исчезновение тел, визуальная толпа и отладка находятся в cl_-файлах. Они обрабатывают серверные события, а не выполняют отдельный клиентский ИИ.
