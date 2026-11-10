# SetState

Realm: **SERVER** (supported usage).

```lua
actor:SetState(state, data, forced)
```

Returns the new {state, data} table or nil when rejected. state=nil means none. forced bypasses normal locks/delays/validator, but mechanics/alive checks and pre-hooks can still reject the transition.

Source: `lua/background_npcs_core/actor/components/sh_state.lua`.

[Realm reference](../../../reference/server.md).
