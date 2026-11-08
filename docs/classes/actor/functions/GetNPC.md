# GetNPC

## SHARED
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
	local npc_color = Color(10, 52, 255)
	local actor = bgNPC.Actors.GetFirst()
	if not actor or not actor:IsValid() then return end
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	npc:SetColor(npc_color)
```