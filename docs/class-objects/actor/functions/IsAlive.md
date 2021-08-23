# IsAlive

## SHARED
```lua
	ACTOR:IsAlive()
```

## Description
Checks if the NPC who is attached to the actor is alive. Calling this check on the server will automatically remove the actor if the NPC is dead.

## Return
1. **boolean** - will return true if the actor is alive.

## Example
```lua
	local actor = bgNPC:GetFirstActorInList()
	if not actor:IsAlive() then return end
	local npc = actor:GetNPC()
	npc:SetHealth(100)
```