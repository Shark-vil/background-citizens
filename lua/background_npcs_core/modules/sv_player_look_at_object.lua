local IsValid = IsValid
local RealTime = RealTime
local player_GetAll =  player.GetAll
local util_TraceLine = util.TraceLine
local hook_Run = hook.Run
--

bgNPC.Tasks.Add('BGN_Timer_PlayerLookAtObject', function(yield, wait)
	local players = player_GetAll()

	for i = 1, #players do
		local ply = players[i]

		if IsValid(ply) and ply:Alive() then
			local tr = util_TraceLine({
				start = ply:EyePos(),
				endpos = ply:EyePos() + ply:EyeAngles():Forward() * 1000,
				filter = function(ent)
					if ent ~= ply then return true end
				end
			})

			yield()

			local ent = tr.Entity
			if tr.Hit and IsValid(ent) then
				local viewed_entity = ply.bgn_look_at_object
				local call_hook_delay = ply.bgn_look_at_object_hook_delay

				yield()

				if not viewed_entity or viewed_entity ~= ent then
					viewed_entity = ent
					call_hook_delay = RealTime()
					ply.bgn_look_at_object = viewed_entity
					ply.bgn_look_at_object_hook_delay = call_hook_delay
				end

				yield()

				if viewed_entity and call_hook_delay then
					local observation_time = RealTime() - call_hook_delay
					if hook_Run('BGN_PlayerLookAtObject', ply, ent, observation_time) then
						ply.bgn_look_at_object_hook_delay = RealTime()
					end
				end
			end
		end

		yield()
	end
end)