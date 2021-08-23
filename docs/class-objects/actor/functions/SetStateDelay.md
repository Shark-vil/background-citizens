# SetStateDelay

## SERVER
```lua
	ACTOR:SetStateDelay(time)
```

## Description
Sets the delay for state change. If there is a delay, then it is impossible to change the state before it expires.

## Arguments
1. **time** number - Delay time.

## Example
**Attention!** This is just an example. Lots of useless calls in every frame is detrimental to the game. It is recommended to use a perpetual timer with the desired delay.

```lua
	local list_of_states = { 'walk', 'run', 'idle' }
	local past_state = nil
	local duplicate_values = 0

	hook.Add("Think", "SetActorTwoStatesDelay", function()
		local actor = bgNPC:GetFirstActorInList()
		local next_state = table.RandomBySeq(list_of_states)

		-- Set to random state on first call.
		-- Subsequent calls will not randomize until the delay expires.
		actor:SetState(next_state)

		-- If the delay has expired or is not active, then set the delay to 3 seconds.
		if not actor:IsStateDelay() then
			actor:SetStateDelay(3)
		end

		-- If the same state is repeated more than 3 times, then the delay is reset.
		if past_state == next_state then
			if duplicate_values == 3 then
				actor:ResetStateDelay()
			else
				duplicate_values = duplicate_values + 1
			end
		else
			duplicate_values = 0
		end

		past_state = next_state
	end)
```