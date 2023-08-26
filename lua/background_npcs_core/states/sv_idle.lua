bgNPC:SetStateAction('idle', 'calm', {
	start = function(actor, state, data)
		local delay = math.random(10, 30)
		data.time = delay
		data.delay = CurTime() + delay

		if slib.chance(15) and GetConVar('bgn_module_custom_gestures'):GetBool() then
			local anim_info = slib.Animator.Play('bgn_check_phone', 'idle', actor:GetNPC())
			if anim_info then
				data.delay = CurTime() + anim_info.time + 1
			end
		else
			if actor.class == 'npc_metropolice' then
				local npc = actor:GetNPC()
				npc:SetKeyValue('additionalequipment', 'weapon_stunstick')
				npc:Give('weapon_stunstick')

				local id = tostring(math.random(1, 2))
				actor:PlayStaticSequence('plazathreat' .. id, true, data.time)

				-- data.delay = CurTime() + actor.anim_time_normal
			else
				local id = tostring(math.random(1, 4))
				actor:PlayStaticSequence('LineIdle0' .. id, true, data.time)
			end
		end
	end,
	update = function(actor, state, data)
		if data.delay > CurTime() then return end

		if actor.class == 'npc_metropolice' then
			local npc = actor:GetNPC()
			local weapon = npc:GetActiveWeapon()
			if IsValid(weapon) then
				weapon:Remove()
			end
		end

		actor:RandomState()
	end
})