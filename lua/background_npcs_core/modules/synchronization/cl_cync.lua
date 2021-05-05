snet.RegisterCallback('bgn_actor_sync_data', function(ply, uid, data)
	local actor = bgNPC:GetActorByUid(uid)
	if not actor then return end

	actor:SetState(data.state)
	actor.enemies = data.enemies
	actor.targets = data.targets
	actor.anim_name = data.anim_name
	actor.is_animated = data.is_animated
	actor.state_lock = data.state_lock
	actor.reaction = data.reaction
	actor.npc_schedule = data.npc_schedule
	actor.npc_state = data.npc_state

	bgNPC:Log('Actor [' .. uid .. '] success synchronization')
end)