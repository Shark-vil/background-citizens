# SyncFunction

Realm: **SERVER** (supported usage).

```lua
actor:SyncFunction(name, ply, data)
```

Server-only compatibility sender: bgNPC.Net.Send(name, ply, self.uid, data). Receive with bgNPC.Net.Receive; SNet is no longer required.

Source: `lua/background_npcs_core/actor/sh_actor.lua`.

[Realm reference](../../../reference/server.md).

## Example (shared postload module)

```lua
if SERVER then
    hook.Add('BGN_SetState', 'MyTownStateTime', function(actor, state)
        actor:SyncFunction('mytown_state_time', nil, {state = state, time = CurTime()})
    end)
else
    bgNPC.Net.Receive('mytown_state_time', function(_, uid, data)
        local actor = bgNPC.Actors.GetByUid(uid)
        if not actor then return end
        print(actor:GetName(), data.state, data.time)
    end)
end
```
