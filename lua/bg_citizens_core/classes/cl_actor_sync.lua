snet.RegisterCallback('bgn_actor_set_state_client', function(ply, npc, state, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor:SetState(state, data)
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_client', function (_, npc, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor.uid = data.uid
		actor.reaction = data.reaction
		actor.anim_time = data.anim_time
		actor.loop_time = data.loop_time
		actor.anim_is_loop = data.anim_is_loop
		actor.is_animated = data.is_animated
		actor.old_state = data.old_state
		actor.state_lock = data.state_lock
		actor.targets = data.targets
		actor.state_data = data.state_data
		actor.npc_schedule = data.npc_schedule
		actor.npc_state = data.npc_state
		actor.anim_name = data.anim_name
		actor.anim_time_normal = data.anim_time_normal
		actor.loop_time_normal = data.loop_time_normal
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_reaction_client', function (_, npc, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor.reaction = data.reaction
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_schedule_client', function (_, npc, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor.npc_schedule = data.npc_schedule
		actor.npc_state = data.npc_state
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_targets_client', function (_, npc, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor.targets = data.targets
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_state_client', function (_, npc, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor.old_state = data.old_state
		actor.state_lock = data.state_lock
		actor.state_data = data.state_data
	end
end)

snet.RegisterCallback('bgn_actor_sync_data_animation_client', function (_, npc, data)
	if not IsValid(npc) then return end
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		actor.anim_time = data.anim_time
		actor.loop_time = data.loop_time
		actor.anim_is_loop = data.anim_is_loop
		actor.is_animated = data.is_animated
		actor.anim_name = data.anim_name
		actor.anim_time_normal = data.anim_time_normal
		actor.loop_time_normal = data.loop_time_normal
	end
end)