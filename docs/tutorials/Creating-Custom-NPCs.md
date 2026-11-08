# Creating a custom actor

Create a separate addon directory, `garrysmod/addons/mytown`. Updates can overwrite edits made inside Background NPCs itself.

The minimal file path is `mytown/lua/background_npcs_core/custom_modules/config/sh_mytown_guard.lua`. Prefix `sh_` loads on server and clients, `sv_` on the server, `cl_` on clients. Use unique filenames and actor IDs.

Module folders load in order: `config` after built-in configuration, `preload` after API and cvars but before main systems, `postload` after main systems. Actor configuration needs only `config`.

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

`SetActor(id, data)` registers a complete configuration. `class` is mandatory. This example uses a fixed `limit` without percentage `fullness`. If you add `inherit`, missing fields are copied from the parent, including its `fullness`: account for that when choosing limits. See [actor options](Actor-Config-Settings.md).

Restart the game after creating the addon directory. Reload the map after Lua edits. Find the new type in the menu and check that it is enabled with a nonzero limit. NextBot behaviour needs a NavMesh; see [bodies and brains](../systems/brains.md).
