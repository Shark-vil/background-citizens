# GetNPC

## SERVER
```lua
	ACTOR:GetNPC()
```

## Description
Returns the NPC entity associated with the actor. Can return "NULL".

## Return
1. **Entity** - entity associated with an actor, or NULL

## Example
Paint the NPC.

```lua
	local npc_color = Color(10, 52, 261)
	local actor = bgNPC:GetFirstActorInList()
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	npc:SetColor(npc_color)
```