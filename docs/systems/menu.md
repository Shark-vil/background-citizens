# Settings menu

Open it with the console command `bgn_menu [page]`, the **Background NPCs** icon in the context menu (C),
or Spawn menu → Options → Background NPCs → Open settings.

The window scales with the screen height (designed at 1080p), has a light and a dark theme
(`bgn_menu_dark`, also the sun / moon button) and soft interface sounds (`bgn_menu_sounds`).
Texts follow the game language: English and Russian.

The search field (Ctrl+F) looks through every page: labels, help texts and cvar names; Esc clears it.
The full screen button (or a double click on the header) maximizes the window.

Server settings (registered with `bgNPC.CVars`) can only be changed by admins; other players see them locked.

## Adding a page

```lua
-- client side, after Background NPCs is loaded
bgNPC.Menu.AddPage('my_addon', {
	title = { en = 'My addon', ru = 'Мой аддон' },   -- or '#phrase' from resource/localization, or plain text
	icon = 'background_npcs/vgui/menu/general.png',  -- optional: a white glyph on transparent, 64x64
	order = 1200,                                    -- built-in pages use 100..1100
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
| `page:Section(title, help)` | Starts a titled card; the following controls go into it. |
| `page:Toggle(cvar, label, opts)` | `opts.on_change(enabled)`. |
| `page:Slider(cvar, label, min, max, opts)` | `opts.decimals` (0), `opts.limit` — the max for typed values (they may pass `max`). The value is sent on release. |
| `page:Button(label, command or function, opts)` | `opts.text` caption, `opts.confirm` (true or a question), `opts.danger`, `opts.admin`. |
| `page:Color(label, { r, g, b }, opts)` | Three integer cvars. |
| `page:Choice(cvar, label, { { value, text }, ... }, opts)` | Segmented control for a few string values; `opts.on_change(value)`. |
| `page:Note(text)` | A muted paragraph between cards. |
| `page:Row(label, help, server, cvar)` | An empty row: put your panel into `row.control`, it is placed on the right. `cvar` is searchable. |
| `page:Custom(function(panel) end)` | Any panel, docked at the top. Hidden while searching. |

Search builds every page with a filter: rows that don't match are created in a hidden panel, so `build`
functions need no changes. `page.filter` is set while searching (skip expensive work there if needed).

Common options: `help` (a `'#key'` label uses `'#key.help'` when it exists), `server` (default: the cvar is a
`bgNPC.CVars` setting; locks the control for non-admins).

Other API: `bgNPC.Menu.Open(page)`, `ShowPage(page)`, `Close()`, `IsOpen()`, `RemovePage(id)`, `Confirm(text, on_yes, danger)`,
`Dialog(width, build)`, `Sound(name)`, `colors` (the current palette), `Builder` (add your own control methods).
