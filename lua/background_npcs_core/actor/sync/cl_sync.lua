bgNPC.Net.Receive('bgn_actor_sync_data', function(ply, uid, data)
	local actor = bgNPC.Actors.ReceiveBinding(data.npc, data.actor_type, uid, nil,
		data.entity_generation, data.class, data.model)
	if not actor then return end

	actor:SetName(data.name)
	actor:SetGender(data.gender)
	actor:SyncState(data.state)
	actor.state_group = data.state_group -- the client has no state registry (states are server files)
	actor.enemies = data.enemies
	actor.targets = data.targets
	actor.anim_name = data.anim_name
	actor.is_animated = data.is_animated
	actor.state_lock = data.state_lock
	actor.reaction = data.reaction
	actor.npc_schedule = data.npc_schedule
	actor.npc_state = data.npc_state

	-- bgNPC.Util.Log('Actor [' .. uid .. '] success synchronization')
end, { wait_entities = true })
