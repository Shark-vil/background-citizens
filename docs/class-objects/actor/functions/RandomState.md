# ACTOR:RandomState

```lua
	ACTOR:RandomState()
```

## Description
Sets the random state of the actor, which are specified in the config settings.

## Example
```lua
	local actor = bgNPC:GetActorByUid(1)
	if actor then
		actor:RandomState()
	end
```