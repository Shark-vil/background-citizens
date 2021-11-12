# SetReaction

## SERVER
```lua
	ACTOR:SetReaction(string reaction)
```

## Description
Sets the reaction of the actor to the event. Used in system computing.

## Arguments
1. **reaction** string - Actor reaction on action.

## Example
Overrides reaction to a damage event. If the attacking player, and the NPC was going to defend, change the future state to "fear".

```lua
	hook.Add("BGN_PreReactionTakeDamage", "SetAnotherDamageReaction", function(attacker, target, reaction)
		local actor = bgNPC:GetActor(target)
		if not actor then return end

		if attacker:IsPlayer() and reaction == 'defense' then
			actor:SetReaction('fear')
		end
	end)
```