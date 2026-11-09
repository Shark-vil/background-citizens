bgNPC.Net.Receive('bgn_actor_sync_data', function(ply, uid, data)
	local actor = bgNPC.Actors.GetByUid(uid)
	if actor and actor:GetNPC() ~= data.npc then
		bgNPC.Actors.Unregister(actor:GetNPC())
		actor = nil
	end
	if not actor and IsValid(data.npc) then
		actor = bgNPC.Actor.Create(data.npc, data.actor_type, uid)
	end
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
