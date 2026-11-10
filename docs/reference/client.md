# Client API

CLIENT handles presentation and received snapshots. It does not own actor AI.

## Actor

### SyncState

`actor:SyncState(state)`

Internal client sync entry: stores the received name without running server state callbacks. Client state data is not a full copy of server state data.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

## Settings window

Source: `lua/background_npcs_core/ui/menu/cl_menu.lua`. See [menu extensions](../systems/menu.md) for a complete page example.

| API | Purpose |
|---|---|
| `bgNPC.Menu.AddPage(id, def)` | Register `{title, order, icon, group, build}`; build receives a page. |
| `bgNPC.Menu.RemovePage(id)` | Remove a registered page. |
| `bgNPC.Menu.Open(page_id)`, `Close()`, `IsOpen()` | Window lifecycle. |
| `bgNPC.Menu.ShowPage(page_id)` | Select an existing page. |
| `bgNPC.Menu.Text(value)`, `Phrase(key)` | Resolve localized display text. |
| `bgNPC.Menu.IsAdmin()` | UI visibility check; server permission checks remain authoritative. |
| `bgNPC.Actors.ReceiveBinding(npc, npc_type, uid, info, generation, class, model)` | Internal receiver: ignores stale generations and rebinds the existing UID. Do not construct client actors independently. |

Voice playback, subtitles, wanted display, corpse fading, ghost crowd and debug overlays live in `cl_` files; they consume server events. They do not provide separate client AI methods.
