local bgNPC = bgNPC
local player_GetHumans = player.GetHumans
local slib_GetHashSumm = slib.GetHashSumm
local IsValid = IsValid
local FrameTime = FrameTime
--
local current_pass = 0
local function has_yield()
	current_pass = current_pass + 1
	if current_pass >= 1 / FrameTime() then
		current_pass = 0
		return true
	end
	return false
end

async.AddDedic('BGN_SynchronizationService', function(yield)
	local sync_list = {}
	local sync_list_count = 0

	do
		local actors = bgNPC:GetAll()
		local players = player_GetHumans()

		for i = 1, #actors do
			local actor = actors[i]
			local sync_players = {}
			local sync_players_count = 0

			if actor and actor:IsAlive() then
				local npc = actor:GetNPC()
				for k = 1, #players do
					local ply = players[k]
					if IsValid(ply) and IsValid(npc) and ply:TestPVS(npc) then
						sync_players_count = sync_players_count + 1
						sync_players[sync_players_count] = ply
					end
					if has_yield() then yield() end
				end
			end

			if sync_players_count ~= 0 then
				sync_list_count = sync_list_count + 1
				sync_list[sync_list_count] = {
					actor = actor,
					players = sync_players
				}
			end

			yield()
		end
	end

	for i = 1, #sync_list do
		local sync_list_value = sync_list[i]
		local actor = sync_list_value.actor

		if actor and actor:IsAlive() then
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
				if ply and IsValid(ply) and ply.snet_ready then
					local old_sync_hash = actor.sync_players_hash[ply] or -1
					if sync_hash ~= old_sync_hash then
						snet.Invoke('bgn_actor_sync_data', ply, actor.uid, sync_data)
						actor.sync_players_hash[ply] = sync_hash
					end
					-- if has_yield() then yield() end
					yield()
				end
			end

			yield()
		end
	end
end)