local original_hook_function

local function init_bsmod_animations()
	original_hook_function = slib.Component('Hook', 'Get', 'EntityTakeDamage', 'DAModuleDamage')
	if not original_hook_function then return end

	hook.Add('EntityTakeDamage', 'DAModuleDamage', function(target, dmginfo)
		if target and IsValid(target) then
			local actor = bgNPC:GetActor(target)
			if actor and ( actor.bsmod_damage_animation_disable
				or actor:GetData().bsmod_damage_animation_disable
			) then
				return
			end
		end

		return original_hook_function(target, dmginfo)
	end)
end
hook.Add('InitPostEntity', 'BGN_BSMOD_DamageAnimationFixedCaller', init_bsmod_animations)