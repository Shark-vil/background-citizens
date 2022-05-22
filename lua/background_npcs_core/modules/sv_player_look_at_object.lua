local IsValid = IsValid
local RealTime = RealTime
local player_GetAll =  player.GetAll
local util_TraceLine = util.TraceLine
local hook_Run = hook.Run
--

async.Add('BGN_Timer_PlayerLookAtObject', function(yield, wait)
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

			local ent = tr.Entity
			if tr.Hit and IsValid(ent) then
				local viewed_entity = ply:slibGetLocalVar('bgn_look_at_object')
				local call_hook_delay = ply:slibGetLocalVar('bgn_look_at_object_hook_delay')

				if not viewed_entity or viewed_entity ~= ent then
					viewed_entity = ply:slibSetLocalVar('bgn_look_at_object', ent)
					call_hook_delay = ply:slibSetLocalVar('bgn_look_at_object_hook_delay', RealTime())
				end

				if viewed_entity and call_hook_delay then
					local observation_time = RealTime() - call_hook_delay
					if hook_Run('BGN_PlayerLookAtObject', ply, ent, observation_time) then
						ply:slibSetLocalVar('bgn_look_at_object_hook_delay', RealTime())
					end
				end
			end
		end

		yield()
	end
end)