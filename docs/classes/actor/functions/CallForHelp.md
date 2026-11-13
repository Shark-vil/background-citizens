# CallForHelp

Realm: **SERVER** (supported usage).

```lua
actor:CallForHelp(enemy)
```

Asks living teammates within 1000 units who have LOS to the caller to react to the enemy. Seeing the enemy is not required; FOV is not checked. The caller needs `call_for_help`, a valid enemy and positive health. `BGN_PreCallForHelp` can cancel; arrest protection, enemy restrictions and protection cooldown still apply.

Source: `lua/background_npcs_core/actor/components/sh_combat.lua`.

[Realm reference](../../../reference/server.md).
