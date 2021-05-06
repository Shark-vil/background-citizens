# Instance

```lua
	BGN_ACTOR:Instance(NPC, NPC_TYPE, CONFIG_DATA, CUSTOM_UID)
```

## Description
Creates an actor object and associates it with the given NPC.

## Arguments
 Type              | Name        | Description                                                                                             
-------------------|-------------|---------------------------------------------------------------------------------------------------------
 Entity            | NPC         | The entity of the NPC to bind the actor                                                                 
 string            | NPC_TYPE    | NPC type, set in the config "*sh_npcs.lua*" as a table key                                              
 table             | CONFIG_DATA | NPC configuration table, as data a copy of NPC table from "*sh_npcs.lua*"                               
 number (Optional) | CUSTOM_UID  | The unique number of the actor. This parameter is used to set the ID that was received from the server. 

## Example
This example demonstrates creating an actor on the server and sending data about him to the client. Further synchronization is performed automatically for specific parameters.

```lua
	if SERVER then
		local npcs = ents.FindByClass('npc_citizen')
		if #npcs == 0 then return end

		local npc = npcs[1]
		local npc_type = 'citizen'
		local npc_data = bgNPC.cfg.npcs_template[npc_type]
		local actor = BGN_ACTOR:Instance(npc, npc_type, npc_data)

		snet.InvokeAll('instance_actor', npc, npc_type, actor.uid)
	else
		snet.Callback('instance_actor', function(npc, npc_type, uid)
			if bgNPC:GetActor(npc) then return end

			local npc_data = bgNPC.cfg.npcs_template[npc_type]
			local actor = BGN_ACTOR:Instance(npc, npc_type, npc_data, uid)
		end).Validator(SNER_ENTITY_VALIDATOR).Register()
	end
```