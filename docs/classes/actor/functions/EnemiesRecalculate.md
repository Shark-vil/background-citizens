# EnemiesRecalculate

Realm: **SERVER** (supported usage).

```lua
actor:EnemiesRecalculate()
```

Updates counts, observes all visible known enemies, drops dead/forgotten enemies and assigns `GetEnemy()` to the body; requires a valid body. Ordinary hidden enemies expire after more than 60 seconds from their observation/report timestamp. Engine pursuit-memory writes do not renew this timestamp. Wanted and always-visible exceptions remain. See [combat memory](../../../systems/brains.md).

Source: `lua/background_npcs_core/actor/components/sh_enemies.lua`.

[Realm reference](../../../reference/server.md).
