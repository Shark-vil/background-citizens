local sync_radius = 700
local sync_distance = sync_radius ^ 2

timer.Create('BGN_SynchronizationService', 3, 0, function()
	local sync_list = {}

	do
		local actors = bgNPC:GetAll()
		local players = player.GetAll()

		for i = 1, #actors do
			local actor = actors[i]
			if actor:IsAlive() then
				local npc = actor:GetNPC()
				local pos = npc:GetPos()
				for k = 1, #players do
					local ply = players[k]
					if ply:GetPos():DistToSqr(pos) <= sync_distance and ply:slibIsViewVector(pos, sync_radius) then
						sync_list[actor] = sync_list[actor] or {}
						array.insert(sync_list[actor], ply)
					end
				end
			end
		end
	end

	for actor, players in pairs(sync_list) do
		local sync_data = {
			state = actor:GetState(),
			enemies = actor.enemies,
			targets = actor.targets,
			anim_name = actor.anim_name,
			is_animated = actor.is_animated,
			state_lock = actor.state_lock,
			reaction = actor.reaction,
			npc_schedule = actor.npc_schedule,
			npc_state = actor.npc_state,
		}

		local sync_hash = slib.GetHashSumm(sync_data)

		for i = 1, #players do
			local ply = players[i]
			if IsValid(ply) and actor:IsAlive() then
				local old_sync_hash = actor.sync_players_hash[ply] or -1
				if sync_hash == old_sync_hash then return end

				snet.Invoke('bgn_actor_sync_data', ply, actor.uid, sync_data)
				actor.sync_players_hash[ply] = sync_hash
			end
		end
	end
end)