snet.RegisterCallback('bgn_actor_set_state_client', function(_, npc, state, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor:SetState(state, data)
end)

snet.RegisterCallback('bgn_actor_sync_data_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.uid = data.uid
	actor.reaction = data.reaction
	actor.anim_time = data.anim_time
	actor.loop_time = data.loop_time
	actor.anim_is_loop = data.anim_is_loop
	actor.is_animated = data.is_animated
	actor.old_state.state = data.old_state
	actor.state_lock = data.state_lock
	actor.targets = data.targets
	actor.state_data.state = data.state
	actor.npc_schedule = data.npc_schedule
	actor.npc_state = data.npc_state
	actor.anim_name = data.anim_name
	actor.anim_time_normal = data.anim_time_normal
	actor.loop_time_normal = data.loop_time_normal
	actor.enemies = data.enemies
end)

snet.RegisterCallback('bgn_actor_sync_data_reaction_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.reaction = data.reaction
end)

snet.RegisterCallback('bgn_actor_sync_data_schedule_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.npc_schedule = data.npc_schedule
	actor.npc_state = data.npc_state
end)

snet.RegisterCallback('bgn_actor_sync_data_targets_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.targets = data.targets
end)

snet.RegisterCallback('bgn_actor_sync_data_state_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.old_state.state = data.old_state
	actor.state_lock = data.state_lock
	actor.state_data.state = data.state
end)

snet.RegisterCallback('bgn_actor_sync_data_animation_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.anim_time = data.anim_time
	actor.loop_time = data.loop_time
	actor.anim_is_loop = data.anim_is_loop
	actor.is_animated = data.is_animated
	actor.anim_name = data.anim_name
	actor.anim_time_normal = data.anim_time_normal
	actor.loop_time_normal = data.loop_time_normal
end)

snet.RegisterCallback('bgn_actor_sync_data_enemies', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if actor == nil then return end

	actor.enemies = data.enemies
end)