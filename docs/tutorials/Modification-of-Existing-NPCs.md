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

## Carried items

`carry_items` enables a combined chance per newly created, unarmed actor. Ordinary citizens default to 5%;
police, medics, gangsters, thieves and taxi drivers override the inherited field with `false`.

```lua
bgNPC.cfg.actors.citizen.carry_items = {
    chance = 5,
    items = { 'ration', 'suitcase' },
    drop_lifetime = 30,
}
-- Set carry_items = false to disable this capability for a custom type.
```

Types with this table expose **Spawn with carried items** in both actor settings menus
(`bgn_carry_items_<type>`, server-owned, default `1`). The switch affects new actors and both ghost modes.
Models must support the item's idle and walk sequences; no model is replaced. NPC and NextBot bodies walk
normally and keep the item during compatible actions. A parcel is stowed for occupied-hand actions and can
return afterwards; a suitcase is dropped instead. Dropped objects collide only with the world and disappear
after `drop_lifetime` seconds (default 30, minimum 1). Local ghosts use a non-colliding client decoration.
Server ghosts synchronize their item and preserve the choice when becoming a real actor, without another roll.

Carry equipment is excluded from `actor:GetActiveWeapon()` / `HasActiveWeapon()` and threat checks; it does
not replace the actor's intended combat weapon. The native entity may still expose its carry weapon.
