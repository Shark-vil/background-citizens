if SERVER then
	local IsValid = IsValid

	bgNPC:SetStateAction('dance', 'calm', {
		pre_start = function(actor, state, data)
			local anim_info = slib.Animator.Play('models/player/kleiner.mdl', 'Taunt_Dance', actor:GetNPC())
			if not anim_info then return 'walk' end

			data.anim_info = anim_info

			return state, data
		end,
		not_stop = function(actor, state, data)
			return IsValid(data.anim_info.animator)
		end
	})
end

scommand.Create('bgn_fun_dance').OnServer(function()
	async.AddDedic('bgn_fun_dance_start', function(yield)
		for _, actor in ipairs(bgNPC:GetAll()) do
			if actor and actor:IsAlive() then
				actor:SetState('dance', nil, true)
			end

			yield()
		end

		return yield('stop')
	end)
end).Access( { isAdmin = true } ).Register()