# GetEnemy

Realm: **SHARED** (supported usage).

```lua
actor:GetEnemy()
```

Returns the selected living enemy or NULL: a direct attacker from the last 5 seconds, then the siege/squad target, then the previous valid combat target, then the nearest living enemy. GetNearEnemy remains the distance-only query. CLIENT uses only its received local data; SERVER owns combat selection.

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Realm reference](../../../reference/shared.md).
