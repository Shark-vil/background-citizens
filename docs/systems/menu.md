# Settings menu

Open it with the console command `bgn_menu [page]`, the **Background NPCs** icon in the context menu (C),
or Spawn menu → Options → Background NPCs → Open settings.

The window scales with the screen height (designed at 1080p), has a light and a dark theme
(`bgn_menu_dark`, also the sun / moon button) and soft interface sounds (`bgn_menu_sounds`).
Texts follow the game language (English and Russian), or the one chosen in **My settings → Menu**
(`bgn_cl_ui_language`: `auto`, `english`, `russian`): the chosen language's
`resource/localization/<lang>/bgn_*.properties` are loaded over the game's. `language.Add` doesn't replace a
phrase the game already loaded, so they are also kept in `bgNPC.Phrases`, which `Menu.Text` reads first.
The interface language doesn't change the NPC phrases: they have `bgn_cl_voice_language` (see voices.md).

The search field (Ctrl+F) looks through every page: labels, help texts and cvar names; Esc clears it.
The full screen button (or a double click on the header) maximizes the window.

The sidebar has three groups: **Server** (settings registered with `bgNPC.CVars`, admins only),
**Only for you** (the "My settings" page: this computer's options) and **More** ("Other works"). Non-admins don't see server settings at all:
a section without visible rows has no heading, a page without visible rows is not listed.
`bgn_menu_as_player [1/0]` (no argument toggles) shows the window as a non-admin sees it, for debugging; the
server still checks the rights.

**Tools → Testing** runs the [testing mode](testing.md): spawn, vehicle, state and settings checks with a copyable log.

## Adding a page

```lua
-- client side, after Background NPCs is loaded
bgNPC.Menu.AddPage('my_addon', {
	title = { en = 'My addon', ru = 'Мой аддон' },   -- or '#phrase' from resource/localization, or plain text
	icon = 'background_npcs/vgui/menu/general.png',  -- optional: a white glyph on transparent, 64x64
	order = 1300,                                    -- built-in pages use 100..1200
	group = '#bgn.menu.group.client',                -- optional sidebar heading: '#bgn.menu.group.server' or your own
	build = function(page)
		page:Section('Movement')
		page:Toggle('my_addon_enabled', 'Enable')
		page:Slider('my_addon_radius', 'Radius', 0, 5000, { help = 'In units.' })
		page:Button('Clear cache', 'my_addon_clear', { confirm = true, danger = true })
	end,
})
```

| Method | Notes |
| --- | --- |
| `page:Section(title, help, accent)` | Starts a titled card (`accent = true` tints it like the quick settings block); the following controls go into it. The heading appears with the first visible row. |
| `page:Toggle(cvar, label, opts)` | `opts.on_change(enabled)`. |
| `page:Slider(cvar, label, min, max, opts)` | `opts.decimals` (0), `opts.limit` — the max for typed values (they may pass `max`). The value is sent on release. |
| `page:Button(label, command or function, opts)` | `opts.text` caption, `opts.confirm` (true or a question), `opts.danger`, `opts.admin`. |
| `page:Color(label, { r, g, b }, opts)` | Three integer cvars. |
| `page:Choice(cvar, label, { { value, text }, ... }, opts)` | Segmented control for a few string values; `opts.on_change(value)`; `opts.get()` gives the active value when `cvar` is a console command. |
| `page:Note(text)` | A muted paragraph between cards. |
| `page:Row(label, help, server, cvar)` | An empty row: put your panel into `row.control`, it is placed on the right. `cvar` is searchable. |
| `page:Custom(function(panel) end)` | Any panel, docked at the top. Hidden while searching. |

Search builds every page with a filter: rows that don't match are created in a hidden panel, so `build`
functions need no changes. `page.filter` is set while searching (skip expensive work there if needed).

Common options: `help` (a `'#key'` label uses `'#key.help'` when it exists), `server` (default: the cvar is a
`bgNPC.CVars` setting; hides the control from non-admins). `opts.admin` does the same for buttons.

Other API: `bgNPC.Menu.Open(page)`, `ShowPage(page)`, `Close()`, `IsOpen()`, `RemovePage(id)`, `Confirm(text, on_yes, danger)`,
`Dialog(width, build)`, `Sound(name)`, `colors` (the current palette), `Builder` (add your own control methods).

## Other works

The last page (`other_works`, `order = math.huge`, `highlight = true` tints it in the sidebar) shows a random
page of the author's Workshop items: preview, title, short description, Subscribe (`steamworks.Subscribe`).
The page count is read from the first page. Previews are cached in `data/bgn_workshop/<id>.jpg|png`;
GIF previews are skipped. A failed load is not retried until the next map, the page says it couldn't load.
Any page can use `highlight = true`.

## First start: mode and setup wizard

On the first map (5 seconds after loading, while `bgn_mode_chosen` is 0) two windows open one after the other:

1. **Mode** (`ui/menu/cl_menu_welcome.lua`): *Classic* (close to version 1.13) or *New*. A mode is only a preset of
   existing settings; "Keep my current settings" changes nothing. Whatever is pressed (or Esc), the wizard follows.
2. **Setup wizard** (`ui/menu/cl_menu_wizard.lua`): a title, a short text, a looped clip and the controls of the step.
   The controls are the settings rows (`Menu.NewBuilder`), so server rows are hidden from non-admins and a step
   without a visible row is skipped. Changes apply at once; closing the wizard does not roll them back.

| Mode | `bgn_actor_body` | `bgn_brain` | `bgn_ghost_crowd` | `bgn_cl_ghost_crowd` | `bgn_cl_voices` |
| --- | --- | --- | --- | --- | --- |
| Classic | `npc` | `fsm` | 0 | 0 | 2 (only Half-Life 2 sounds) |
| New | `auto` | `auto` | 1 | 1 | 1 (generated voices) |

Server settings are applied only for an admin; everybody gets the client ones. The choice is kept in `bgn_mode`
(`classic` / `new`).

Steps: crowd density, wanted and arrest, voices and sound, vehicles. The *body*, *brain* and *ghost crowd* steps are
`advanced`: the mode already decides them, so the wizard shows them only as `bgn_wizard all`. Steps with
`modern = true` (body, brain, ghosts, voices) are skipped in Classic, except for `bgn_wizard all`.
The vehicles step has Workshop cards: Decent Vehicle (required) and a pack of three items (simfphys, GTA SA cars,
Background NPCs support) that is subscribed at once.

| Command | Opens |
| --- | --- |
| `bgn_mode_welcome` | The mode window only |
| `bgn_wizard` | The wizard for the current mode |
| `bgn_wizard all` | The wizard with every step |
| `bgn_mode_chosen 0` | Nothing now: both windows come back on the next map |

The same two windows can be opened from the **Quick settings** block (General page) and from My settings.

Add a step: an entry of `STEPS` in `cl_menu_wizard.lua` (`id`, `clip`, `frames`, `labels`, `modern`, `advanced`,
`build(page)`) and the phrases `bgn.wizard.<id>` and `bgn.wizard.<id>.desc` (plus `.l1` / `.l2` for the labels).

### Clips

GMod can't play video, so a clip is a frame atlas: `materials/background_npcs/wizard/<clip>.jpg`, 2048x2048,
5 columns of 384x216 frames, 45 frames played at 10 fps. With `labels` the first label is shown over the first half
of the frames and the second over the rest ("before" / "after"). A missing atlas draws a plain placeholder.

`python tools/make_wizard_clips.py <addon root> <clip> <frames dir> [<frames dir> ...]` builds an atlas: every
folder gives an equal share of the frames (two folders: before, after), the first two frames of each folder are
dropped. The clips were recorded in game on gm_bigcity_improved: a fixed time step (`host_framerate 10`), a
screenshot per frame, a free camera and hand-made scenes (NPCs placed in front of the camera, a staged
firefight, a chase with the wanted level set).

## Crowd density

General page, single player only (it changes server and client settings together): one choice sets
`bgn_max_npc` (type limits follow it), `bgn_ghost_crowd_max` and `bgn_cl_ghost_crowd_max`.
Low 15 / 0 ghosts, Medium 35 / 40 (defaults), High 60 / 80, Ultra 100 / 150. Console: `bgn_crowd_density low|medium|high|ultra`.
No preset is selected when the limits were changed by hand. Presets: `DENSITY` in `ui/menu/cl_menu_pages.lua`.
