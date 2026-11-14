# HasEnemy

Realm: **SHARED** (supported usage).

```lua
actor:HasEnemy(ent)
```

Returns whether ent is in the enemy list. SERVER returns false for a current teammate even if an old list entry remains; CLIENT reads its received list snapshot.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Realm reference](../../../reference/shared.md).
