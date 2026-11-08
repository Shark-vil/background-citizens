# Editing existing actors

Create a shared file in `custom_modules/config`, as described in [creating an actor](Creating-Custom-NPCs.md). For scalar fields use:

```lua
bgNPC.cfg:EditActor('citizen', { health = 80, random_skin = true })
```

`EditActor` merges data through `table.Merge`, including nested tables. To replace whole model, team or reaction lists, assign a new table directly:

```lua
-- lua/background_npcs_core/custom_modules/config/sh_mytown_citizens.lua
local citizen = bgNPC.cfg.actors['citizen']
citizen.health = 80
citizen.default_models = false
citizen.models = { 'models/Humans/Group01/male_07.mdl' }
citizen.at_random = { walk = 80, idle = 20 }
```

Do not use `SetActor` for a partial edit: it replaces the complete configuration. Reload the map to check changes. Built-in configs live in `lua/background_npcs_core/config/actors/`, for example `sh_citizen.lua`.
