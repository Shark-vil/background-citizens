# GetNPC

## SHARED
```lua
	ACTOR:GetNPC()
```

## Description
Returns the entity currently associated with the actor: an NPC/NextBot on foot or a DV driver/passenger anim entity while seated. Can return "NULL". Boarding removes the old body and exiting recreates it; fetch this value again after either transition. The actor object and UID remain stable.

## Return
1. **Entity** - entity associated with an actor, or NULL

## Example
Paint the NPC.

```lua
	local npc_color = Color(10, 52, 255)
	local actor = bgNPC.Actors.GetFirst()
	if not actor or not actor:IsValid() then return end
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	npc:SetColor(npc_color)
```

[Realm reference](../../../reference/shared.md).
