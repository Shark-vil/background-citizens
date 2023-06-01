local bgNPC = bgNPC
local player_GetAll = player.GetAll
local slib_GetHashSumm = slib.GetHashSumm
local isfunction = isfunction
--
local sync_radius = 700
local sync_distance = sync_radius ^ 2

timer.Create('BGN_SynchronizationService', 1.5, 0, function()
	local sync_list = {}
	local sync_list_count = 0

	do
		local actors = bgNPC:GetAll()
		local players = player_GetAll()

		for i = 1, #actors do
			local actor = actors[i]
			local sync_players = {}
			local sync_players_count = 0

			if actor and isfunction(actor.IsAlive) and actor:IsAlive() then
				local npc = actor:GetNPC()
				local pos = npc:GetPos()
				for k = 1, #players do
					local ply = players[k]
					if ply:GetPos():DistToSqr(pos) <= sync_distance and ply:slibIsViewVector(pos) then
						sync_players_count = sync_players_count + 1
						sync_players[sync_players_count] = ply
					end
				end
			end

			if sync_players_count ~= 0 then
				sync_list_count = sync_list_count + 1
				sync_list[sync_list_count] = {
					actor = actor,
					players = sync_players
				}
			end
		end
	end

	for i = 1, #sync_list do
		local sync_list_value = sync_list[i]
		local actor = sync_list_value.actor

		if actor and isfunction(actor.IsAlive) and actor:IsAlive() then
			local players = sync_list_value.players
			local sync_data = {
				name = actor:GetName(),
				gender = actor:GetGender(),
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

			local sync_hash = slib_GetHashSumm(sync_data)

			for k = 1, #players do
				local ply = players[k]
				if ply and ply.snet_ready then
					local old_sync_hash = actor.sync_players_hash[ply] or -1
					if sync_hash ~= old_sync_hash then
						snet.Invoke('bgn_actor_sync_data', ply, actor.uid, sync_data)
						actor.sync_players_hash[ply] = sync_hash
					end
				end
			end
		end
	end
end)