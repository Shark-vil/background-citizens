# Practical examples

## Reduce load

Run `bgn_crowd_density low` in the client console: a limit of 25 actors and no ghosts (an admin sets the server limit; any other player changes only their own ghosts, and only while the server does not run the ghost crowd). Restore the medium preset with `bgn_crowd_density medium` (35 actors, 40 ghosts). Type limits follow the total; existing actors need not disappear immediately.

## Russian interface, English voices

```text
bgn_cl_ui_language russian
bgn_cl_voice_language english
bgn_cl_voices 1
```

Run in the client console. Set both language options to `auto` to follow the game language. The server's `bgn_module_replics_language` overrides phrase language for everyone when it is not `auto`.

## Citizens with one model and simple behaviour

Create a separate addon using the [module guide](tutorials/Creating-Custom-NPCs.md), then add this file:

```lua
-- lua/background_npcs_core/custom_modules/config/sh_mytown_citizens.lua
local citizen = bgNPC.cfg.actors['citizen']
citizen.health = 80
citizen.default_models = false
citizen.models = { 'models/Humans/Group01/male_07.mdl' }
citizen.at_random = { walk = 80, idle = 20 }
```

These assignments replace whole tables. `EditActor` uses `table.Merge`, which can retain old keys and list entries. Reload the map after config changes; restart the game when adding a new addon directory.

## Two armed guards

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

`class` is required by `SetActor`. This independent configuration uses a fixed `limit`; do not add `fullness`, which takes priority over it. Reaction values are relative weights, not a guarantee of winning a fight.

## Find an actor and change its name

Put this in server-side `custom_modules/postload/sv_mytown_inspect.lua`. Only admins or the server console can run it:

```lua
concommand.Add('mytown_inspect', function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local actor = bgNPC.Actors.GetFirst()
    if not actor or not actor:IsValid() then
        print('No actors spawned yet')
        return
    end
    local npc = actor:GetNPC()
    if not IsValid(npc) then return end
    actor:SetName('Town resident')
    print(actor:GetType(), npc:GetPos())
end)
```
