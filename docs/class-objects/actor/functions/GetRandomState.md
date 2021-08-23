# GetRandomState

## SERVER
```lua
	ACTOR:GetRandomState()
```

## Description
Gets a random actor state.

**Attention!** The state *"none"* is considered systemic, and means the absence of a state. It is recommended to add a check for the *"none"* state if you are going to use this method.

## Return
1. **string** - any state name or "none" string

## Example
```lua
	local actor = bgNPC:GetFirstActorInList()
	local new_state = actor:GetRandomState()
	if new_state == "none" then return end
	actor:SetState(new_state)
```