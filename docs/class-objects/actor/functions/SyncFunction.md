# SyncFunction

## SERVER
```lua
	ACTOR:SyncFunction(name, ply, data)
```

## Description
This function is a system function and is used to synchronize data. A unique identifier of the actor and a data table are sent to the client as parameters.

## Arguments
1. **name** string - The name of the network variable of the library "SNet", where the request should be sent.
2. **ply** Player *(Optional | Default: nil)* - the player for which the data should be sent. If a player is not specified, then the data is sent to all players.
3. **data** table - table with data to be sent to the network hook.

## Example
In this example, the code is executed on the server and client. The synchronization function is called after the actor's state has changed, and as data we send the client the new state and the server time when it was set.

```lua
	if SERVER then
		hook.Add('BGN_SetNPCState', 'SendForClientNewStateSetTimeInfo', function(actor, state_name)
			actor:SyncFunction('actor_get_new_state_time_set', nil, {
				state_name = state_name,
				time_set = RealTime()
			})
		end)
	else
		snet.RegisterCallback('actor_get_new_state_time_set', function(ply, uid, data)
			local actor = bgNPC:GetActorByUid(uid)
			if not actor then return end
			print('The new state "' .. data.state_name .. '" was set at "' .. data.time_set .. '" time')
		end)
	end
```