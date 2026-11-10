# WalkToPos

Realm: **SERVER** (supported usage).

```lua
actor:WalkToPos(pos, move_type, path_type)
```

Starts travel to a Vector or node:GetPos(); nil stops. Requires a navigable path. Finishing is reported through BGN_ActorFinishedWalk.

Source: `lua/background_npcs_core/actor/components/sh_movement.lua`.

[Realm reference](../../../reference/server.md).
