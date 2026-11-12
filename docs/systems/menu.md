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
Language synchronization sends only the language code to SERVER (`bgn_cl_language`), so server-generated Tool reports use the selected mod language as well.

The search field (Ctrl+F) looks through every page: labels, help texts and cvar names; Esc clears it.
The full screen button (or a double click on the header) maximizes the window.

The sidebar has three groups: **Server** (settings registered with `bgNPC.CVars`, admins only),
**Only for you** (the "My settings" page: this computer's options) and **More** ("Other works"). Non-admins don't see server settings at all:
a section without visible rows has no heading, a page without visible rows is not listed.
`bgn_menu_as_player [1/0]` (no argument toggles) shows the window as a non-admin sees it, for debugging; the
server still checks the rights.

**Tools → Testing** runs the [testing mode](testing.md): spawn, vehicle, state and settings checks with a copyable log.

Spawnmenu **Options → Background NPCs → Debugging** collects debug overlays, NPC paths, actor WH,
the state/decision inspector, sight visualization and an actor first-person camera. See [debug controls](testing.md#spawnmenu-debug-page).

**Modules** lists the switchable modules: Wanted, Arrest, Scenic NPCs, Decent Vehicle and the supported addons. The switch of a module is shown to everybody and is locked for a player who is not an admin. A gear opens the module's own page (opened from the page, not listed in the sidebar; search finds its rows) with a **Server** section (admins) and an **Only for you** section (this computer's options, e.g. the wanted HUD and halo). The gear is shown only when the player has something on that page: any server row for an admin, a client row for everybody; Decent Vehicle has server rows only while Decent Vehicle is loaded (`DecentVehicleDestination`).
**Modules → Scenic NPCs (gear)** has a checkbox for each automatically eligible scene (`bgn_scenic_<id>`).
**Actors** shows the vehicle count of a type with a blue **Decent Vehicle** badge (only while Decent Vehicle is loaded) and **Spawn with carried items** (`bgn_carry_items_<type>`) only for types with a `carry_items`
config table. Both controls also exist in Classic settings and affect future spawning, including ghost items.
Tools are split into **Background NPCs: Editor** (route points, spawn areas, seats) and **Background NPCs: Debugging** (actor inspector, navigation, movement, scenes, carried items). The debug page shares UID selection, visualization modes, distance/limit filters and freeze controls with the inspector Tool.


## Spawn and recycling settings

The **Spawn** page holds the pedestrian settings; the vehicle visibility radius is in **Modules → Decent Vehicle (gear)**. Server defaults:

| Cvar | Default | Meaning |
| --- | --- | --- |
| `bgn_spawn_radius` | 3000 | Radius used to find spawn points around players. |
| `bgn_spawn_block_radius` | 600 | No pedestrian spawns this close to any player. |
| `bgn_spawn_radius_visibility` | 2000 | Visibility radius of players. Used only by [wanted](wanted.md): a wanted NPC/actor (not a player) is dropped after 15 s outside every player's field of view or farther than half of this radius; obstacles are not checked. |
| `bgn_vehicle_spawn_visibility_radius` | 2000 | Within this distance in a player's view direction vehicles spawn only when the whole car body (a grid of points over its size) is hidden behind cover; affects vehicles only. |
| `bgn_actor_unseen_time` | 30 | Seconds unseen by every player before an eligible actor can be removed or teleported; `0` permits immediate recycling out of sight. |
| `bgn_vehicle_cleanup_time` | 120 | Cleanup timeout for an unseen BGN car left without a driver or failing to move more than 128 units from its anchor; `0` disables this additional cleanup. |

Pedestrian spawn and teleport checks test feet, chest and head against visible obstructions; vehicle spawns test a grid over the car body. A point in a player's view counts as covered only when the obstruction stops the sight line at least 40 units short of it, and the player's own car does not count as cover. Outside the view cone, points beyond the block radius remain eligible. Candidate checks do not yield midway. Busy actors (conversation, arrest, revival and scenic work), seated actors and locked states are protected from normal recycling. The unseen timeout applies to over-limit actors too; disabling the addon or an actor type follows its separate removal path. Vehicle cleanup checks the chassis against all players, including partially exposed cars and occupied seats.

## Adding a page

```lua
-- client side, after Background NPCs is loaded
bgNPC.Menu.AddPage('my_addon', {
	title = { en = 'My addon', ru = 'Мой аддон' },   -- or '#phrase' from resource/localization, or plain text
	icon = 'background_npcs/vgui/menu/general.png',  -- optional: a white glyph on transparent, 64x64
	order = 1300,                                    -- built-in pages use 100..1200
	group = '#bgn.menu.group.client',                -- optional sidebar heading: '#bgn.menu.group.server' or your own
	hidden = true,                                   -- optional: not listed in the sidebar (open it with ShowPage; search still finds it)
	parent = 'modules',                              -- optional: the sidebar item shown as active while this page is open
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

## Interface size and migration

`bgn_cl_ui_scale` (0.75 - 2, default 1, Settings, My settings) multiplies the menu scale, which otherwise follows the screen height; the menu reopens on change.

One-time migration (`systems/sh_settings_migration.lua`): while `bgn_settings_rev` (server) / `bgn_cl_settings_rev` (client) is 0, the settings that 2.x turned on by itself go back to the old behavior: ghost crowd off, `bgn_actor_body auto` -> `npc`, `bgn_brain auto` -> `fsm`. Choosing *New* in the mode window marks the choice as deliberate and keeps it.

## First start: mode and setup wizard

On the first map (5 seconds after loading, while `bgn_mode_chosen` is 0) two windows open one after the other, only for the owner of the game (singleplayer or the listen server host). A player who joins a server is never greeted; the windows stay available from the menu and the console:

1. **Mode** (`ui/menu/cl_menu_welcome.lua`): *HL2 NPC* (regular Half-Life 2 NPCs like version 1.x: replacers and mods for standard NPCs keep working, lightest on the PC) or *NextBot* (the mod's own body: ghost crowd, GOAP, staged scenes; replacers do not affect it, heavier). Both are equal and fully supported (internal keys `classic` / `new`), the window only explains the difference; the defaults are the classic ones, and the mode can be changed any time (Settings, About, or `bgn_mode_welcome`). A mode is only a preset of
   existing settings (it also sets `bgn_settings_rev` / `bgn_cl_settings_rev` to 1); "Keep my current settings" changes nothing. Whatever is pressed (or Esc), the wizard follows.
2. **Setup wizard** (`ui/menu/cl_menu_wizard.lua`): a title, a short text, a looped clip and the controls of the step.
   The controls are the settings rows (`Menu.NewBuilder`), so server rows are hidden from non-admins and a step
   without a visible row is skipped. Changes apply at once; closing the wizard does not roll them back.

| Mode | `bgn_actor_body` | `bgn_brain` | `bgn_ghost_crowd` | `bgn_cl_ghost_crowd` |
| --- | --- | --- | --- | --- |
| Classic | `npc` | `fsm` | 0 | 0 |
| New | `nextbot` | `auto` | 1 | 1 |

Both modes use the same voiced conversations. Switching modes preserves the voice setting.

Server settings are applied only for an admin; everybody gets the client ones. The choice is kept in `bgn_mode`
(`classic` / `new`).

Steps: crowd density, scenic scenes, wanted and arrest, voices and sound, vehicles. The *body*, *brain* and *ghost crowd* steps are
`advanced`: the mode already decides them, so the wizard shows them only as `bgn_wizard all`. Steps with
`modern = true` (body, brain, ghosts, scenic scenes) are skipped in Classic, except for `bgn_wizard all`.
The vehicles step has Workshop cards: Decent Vehicle (required) and a pack of three items (simfphys, GTA SA cars,
Background NPCs support) that is subscribed at once.

| Command | Opens |
| --- | --- |
| `bgn_mode_welcome` | The mode window only |
| `bgn_wizard` | The wizard for the current mode |
| `bgn_wizard all` | The wizard with every step |
| `bgn_mode_chosen 0` | Nothing now: both windows come back on the next map |

The same two windows can be opened from the **Quick settings** block and from My settings. The block is at the top of the General page until it is closed with its cross (`bgn_menu_quick_hidden`, a client setting), and is always at the top of the Tools page.

## Classic spawn menu pages

Spawn menu → Options → Background NPCs also keeps the pages of the old versions (General, Actors, Spawn, Wanted, Arrest, Extensions, Optimization, Addons, Client, Workshop) for those who are used to them. They are generated from the `PAGES` table in `ui/settings/cl_classic_settings.lua`: an item is `{ kind, cvar_or_command, phrase_key, ... }` (`check`, `slider`, `button`, `actors`), a page marked `admin = true` shows a note to non-admins. Text comes from `resource/localization/<lang>/bgn_*.properties` (English and Russian, or the language chosen in the settings window). An item whose cvar or command no longer exists is skipped. The *Settings* page there opens the new window. Admin command `bgn_classic` / chat `!bgn_classic` applies the classic preset (`bgNPC.ClassicPreset` in `systems/sh_classic_mode.lua`, the same one the *Classic* mode uses).

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

One choice (General page for an admin, Client page for everybody else, and the first wizard step) sets
`bgn_max_npc` (type limits follow it), `bgn_ghost_crowd_max` and `bgn_cl_ghost_crowd_max`. It works on any server,
by who presses it: an **admin** changes the server limits and his own ghosts; a **player** changes only his own ghosts
(`bgn_cl_ghost_crowd_max`), and only while the server does not run the ghost crowd (`bgn_ghost_crowd 0`). When the
server runs the ghosts and the player is not an admin, the choice is locked with the reason.
Low 25 / 0 ghosts, Medium 35 / 40 (defaults), High 60 / 80, Ultra 100 / 150. Console: `bgn_crowd_density low|medium|high|ultra`.
No preset is selected when the limits were changed by hand. Presets: `DENSITY` in `ui/menu/cl_menu_pages.lua`.

## Setting change notices

Every change of a setting shows a notice in the bottom right corner, drawn above the menus: a **blue** *SERVER*
plate (`#03a9f4`) for a server setting (also one changed by the testing mode's *Fix* button), announced to all players
after the server has applied it, and an **amber** *CLIENT* plate (`#dea909`) for a `bgn_cl_*` setting, shown only to its
player. A plate has the name and `old > new`; a slider updates one plate instead of stacking new ones, and the limits that
the mod rewrites by itself after `bgn_max_npc` are not announced. If an admin's copy is stale, the server sends the real
value back quietly.

The notices are standalone (`core/sh_notice.lua`): the file is included first, has its own network string, language
check and drawing, and a drawing error is caught, so a failure of any later script cannot silence them. For your own
cvar call `bgNPC.Notice.Watch(name)` (server cvar: everybody sees it; client cvar: its player).
