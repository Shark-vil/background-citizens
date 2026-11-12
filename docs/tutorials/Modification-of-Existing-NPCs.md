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
    items = { 'ration', 'suitcase', 'newspaper' },
    drop_lifetime = 30,
}
-- Set carry_items = false to disable this capability for a custom type.
```

Types with this table expose **Spawn with carried items** in both actor settings menus
(`bgn_carry_items_<type>`, server-owned, default `1`). The switch affects ordinary new actors. Both ghost modes and actors materialized from server ghosts always have empty hands.
NextBots require idle/walk sequences for food and newspapers; a briefcase only requires the right-hand bone. `newspaper` uses the two-handed parcel pose
with the parcel hidden and the stock HL2 newspaper fitted between both hands. No models/assets are replaced. The newspaper's lower edge follows the fingertips, its text is upright, and the top leans 15 degrees away from the face. The native briefcase hangs upright from the right index-finger grip, including during ordinary NPC walking.
Ordinary HL2 NPCs support only `suitcase`: a CLIENT-only `briefcase001a` follows the right-hand bone, without
giving the NPC a carry weapon or overriding its movement/activity. Other item kinds are excluded before selection.
A parcel/newspaper is stowed for occupied-hand actions or a NextBot's run and can return afterwards. On either body, the CLIENT-only briefcase stays attached through calm actions and running, without a carry weapon or luggage sequence requirement. It is removed on danger, guarded, assault or retreat states, death or actor removal, and never becomes a dropped object. Real actors' client-only props use existing PVS actor snapshots and hide with the parent.

Admins can use **Background NPCs → Carried item debugger** (`bgn_carry_debug`): select briefcase, food parcel or newspaper, then left-click a living unarmed actor on foot in a calm state. This bypasses carry spawn chance and its checkbox; body/model support still applies. Right-click removes the item. Issuing an item starts walking and suppresses subsequent automatic item selection.

Carry equipment is excluded from `actor:GetActiveWeapon()` / `HasActiveWeapon()` and threat checks; it does
not replace the actor's intended combat weapon. The native entity may still expose its carry weapon.
