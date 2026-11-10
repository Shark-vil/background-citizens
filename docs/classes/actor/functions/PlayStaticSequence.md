# PlayStaticSequence

Realm: **SERVER** (supported usage).

```lua
actor:PlayStaticSequence(sequence_name, loop, loop_time, action)
```

Returns boolean; loop_time nil or 0 loops indefinitely. Requires a body and supported sequence. An action callback returning true can reject stopping.

Source: `lua/background_npcs_core/actor/components/sh_animation.lua`.

[Realm reference](../../../reference/server.md).
