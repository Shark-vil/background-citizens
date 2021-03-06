hook.Add("BGN_PreSetNPCState", "BGN_IdleStateDayaValidate", function(actor, state, data)
	if actor:HasState('idle') then
		if table.HasValue(bgNPC.cfg.npcs_states['calmly'], state) then
			return true
		end
	end

	if state ~= 'idle' then return end

	local delay = math.random(10, 30)

	return {
		state = state,
		data = {
			time = delay,
			delay = CurTime() + delay
		}
	}
end)

hook.Add("BGN_SetNPCState", "BGN_SetIdleNPCAnimationIfStateEqualIdle", function(actor, state, data)
	if state ~= 'idle' then return end
	local id = tostring(math.random(1, 4))
	actor:PlayStaticSequence('LineIdle0' .. id, true, data.time)
end)

timer.Create('BGN_ChangeIdleStateToWalk', 1, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('idle')) do
		if actor:GetStateData().delay < CurTime() then
			actor:RandomState()
		end
	end
end)