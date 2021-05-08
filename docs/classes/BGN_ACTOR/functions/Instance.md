# Instance

## SERVER
```lua
	BGN_ACTOR:Instance(npc, npc_type, custom_uid, not_sync_actor_on_client, not_auto_added_to_list)
```

## Description
Creates an actor object and associates it with the given NPC.

## Arguments
1. **npc** Entity - The entity of the NPC to bind the.
2. **npc_type** string - NPC type, set in the config "*sh_npcs.lua*" as a table key.
3. **custom_uid** number *(Optional)* - The unique number of the actor. This parameter is used to set the ID that was received from the server.
4. **not_sync_actor_on_client** boolean *(Optional | Default: false)* - if the value is set to "true", then no information about the actor will be sent to clients.
5. **not_auto_added_to_list** boolean *(Optional | Default: false)* - if the value is set to "true", then the actor will not be automatically added to the general list of all actors.

## Example
The code is executed on the server. In this example, an actor with the "citizen" behavior will bind to all NPCs that the player spawns from the spawn menu, after which a message with his unique identifier will be displayed on the console.

```lua
	-- 
	hook.Add('PlayerSpawnedNPC', 'BindingActorToNPCFromTheSpawnMenu', function(ply, npc)
		local actor = BGN_ACTOR:Instance(npc, 'citizen')
		print('A new actor has been created with ID - ', actor.uid)
	end)
```