if SERVER then

	bgNPC.States.Register('dance', 'calm', {
		pre_start = function(actor, state, data)
			local anim_info = bgNPC.Animator.Play('models/player/kleiner.mdl', 'Taunt_Dance', actor:GetNPC())
			if not anim_info then return 'walk' end

			data.anim_info = anim_info

			return state, data
		end,
		update = function(actor, state, data)
			if IsValid(data.anim_info.animator) then return end
			actor:RandomState()
		end
	})
end

bgNPC.Commands.Register('bgn_fun_dance', { admin = true, server = function()
	bgNPC.Tasks.Add('bgn_fun_dance_start', function(yield, wait)
		for _, actor in ipairs(bgNPC.Actors.GetAll()) do
			if actor and actor:IsAlive() then
				actor:SetState('dance', nil, true)
				yield()
			end
			wait(.2)
		end
	end)
end })