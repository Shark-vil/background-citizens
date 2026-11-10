# Instance

**SERVER**, legacy compatibility alias. Prefer:

```lua
local actor = bgNPC.Actor.Create(npc, 'citizen')
if not actor then return end
```

Equivalent compatibility call: `BGN_ACTOR:Instance(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)`.

`npc` is a valid entity, `npc_type` is an actor configuration ID. Optional `custom_uid` supplies an identity; the two optional booleans suppress initial client sync and automatic registration. Leave them unset for normal addons. Returns an actor or nil for invalid input; do not bind an already registered entity.

Implementation: `actor/sh_actor.lua`, `Actor.Create` / `Actor:Init`. [Server API](../../reference/server.md).
