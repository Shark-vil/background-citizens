snet.RegisterCallback('bgn_actor_sync_data_reaction_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

	actor.reaction = data.reaction
end)

snet.RegisterCallback('bgn_actor_sync_data_schedule_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

	actor.npc_schedule = data.npc_schedule
	actor.npc_state = data.npc_state
end)

snet.RegisterCallback('bgn_actor_sync_data_targets_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

	local old_count = #actor.targets
	actor.targets = data.targets

	if old_count > 0 and #data.targets <= 0 then
		hook.Run('BGN_ResetTargetsForActor', actor)
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_state_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

	actor.state_data = data.state
	actor.old_state = data.old_state
	actor.state_lock = data.state_lock

	hook.Run('BGN_SetNPCState', actor, actor.state_data.state, actor.state_data.data)
end)

snet.RegisterCallback('bgn_actor_easy_sync_data_state_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

	actor.state_data.state = data.state
	actor.old_state.state = data.old_state
	actor.state_lock = data.state_lock

	hook.Run('BGN_SetNPCState', actor, actor.state_data.state, actor.state_data.data)
end)

snet.RegisterCallback('bgn_actor_sync_data_animation_client', function (_, npc, data)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

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
	if not actor then return end

	local old_count = #actor.enemies
	actor.enemies = data.enemies

	if old_count > 0 and #data.enemies <= 0 then
		hook.Run('BGN_ResetEnemiesForActor', actor)
	end
end)