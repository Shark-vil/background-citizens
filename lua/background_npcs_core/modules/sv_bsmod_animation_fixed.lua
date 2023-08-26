local function init_bsmod_animations()
	local original_hook_function = slib.Component('Hook', 'Get', 'EntityTakeDamage', 'DAModuleDamage')
	if not original_hook_function then return end

	hook.Add('EntityTakeDamage', 'DAModuleDamage', function(target, dmginfo)
		if target and IsValid(target) then
			local actor = bgNPC:GetActor(target)
			if actor then
				local data = actor:GetData()
				if actor.bsmod_damage_animation_disable or (data and data.bsmod_damage_animation_disable) then
					return
				end
			end
		end

		return original_hook_function(target, dmginfo)
	end)
end
hook.Add('InitPostEntity', 'BGN_BSMOD_DamageAnimationFixedCaller', init_bsmod_animations)