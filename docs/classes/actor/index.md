# Actor API

An actor is a stable character record associated with an engine entity. Bodies and brains exist on the server; the client receives presentation data.

- [Server methods](../../reference/server.md): construction, state changes, movement, combat, vehicles, speech and removal.
- [Client methods](../../reference/client.md): state snapshots and settings UI.
- [Shared methods](../../reference/shared.md): identity, health, state/enemy/target queries and public namespaces.

Get an actor using `bgNPC.Actors.Get(entity)`, `GetByUid(uid)` or `GetFirst()`. A lookup may return nil. Validate `actor:GetNPC()` with `IsValid`.

Use `bgNPC.Actor.Create(npc, actor_type)` on the server to bind a new entity. [BGN_ACTOR:Instance](Instance.md) remains a compatibility alias. Do not register an entity twice.

Boarding a DV vehicle keeps the actor and UID, replaces the entity with a DV visual and recreates the saved NPC/NextBot on exit. Fetch the entity again after `BGN_ActorEntityChanged(actor, old, new)`; addon-private entity state needs its own integration. Use `Health()` / `GetMaxHealth()` instead of assuming the visual has NPC methods.

Client snapshots are sent on a 0.25-second service cycle to ready players in PVS when data changes. They contain identity, entity generation, state name/group, enemies/targets and animation flags; server body/brain, full state data and configuration mutations are not mirrored in full.

See [examples](../../examples.md) and [architecture](../../architecture.md).
