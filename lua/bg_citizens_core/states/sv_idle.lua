hook.Add("BGN_PreSetNPCState", "BGN_IdleStateDayaValidate", function(actor, state, data)
	if state ~= 'idle' then return end
	
	return {
		state = state,
		data = {
			delay = CurTime() + 10
		}
	}
end)

hook.Add("BGN_SetNPCState", "BGN_SetIdleNPCAnimationIfStateEqualIdle", function(actor, state, data)
	if state ~= 'idle' then return end
	local id = tostring(math.random(1, 4))
	actor:PlayStaticSequence('LineIdle0' .. id, true, 10)
end)

timer.Create('BGN_ChangeIdleStateToWalk', 1, 0, function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		local state = actor:GetState()
		local data = actor:GetStateData()
		if state == 'idle' and data.delay < CurTime() then
			actor:RandomState()
		end
	end
end)