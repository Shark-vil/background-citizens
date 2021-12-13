local function idle_is_finish(actor, data)
	return data.delay < CurTime()
end

bgNPC:SetStateAction('idle', 'calm', {
	start = function(actor, state, data)
		local delay = math.random(10, 30)
		data.time = delay
		data.delay = CurTime() + delay

		if slib.chance(15) then
			local anim_info = slib.Animator.Play('bgn_check_phone', 'idle', actor:GetNPC())
			if anim_info then
				data.delay = CurTime() + anim_info.time + 1
			end
		else
			local id = tostring(math.random(1, 4))
			actor:PlayStaticSequence('LineIdle0' .. id, true, data.time)
		end
	end,
	update = function(actor, state, data)
		if idle_is_finish(actor, data) then actor:RandomState() end
	end,
	not_stop = function(actor, state, data)
		return not idle_is_finish(actor, data)
	end
})