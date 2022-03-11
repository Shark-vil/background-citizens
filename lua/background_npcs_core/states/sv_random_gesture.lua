local gestures = {
	'Taunt_Dance',
	'Taunt_Laught',
	'Taunt_Muscle',
	'Taunt_Robot',
	'Taunt_Zombie',
	'Taunt_Cheer',
	'Menu_Gman',
	'Sit_Zen',
}

bgNPC:SetStateAction('random_gesture', 'calm', {
	pre_start = function(actor, state)
		local data = {}
		data.dancing_time = 0

		local npc = actor:GetNPC()
		local animation_name = table.RandomBySeq(gestures)
		local animation_time = nil
		if animation_name == 'Sit_Zen' then
			animation_time = math.random(10, 60)
		end

		local anim_info = slib.Animator.Play('models/player/kleiner.mdl', animation_name, npc, {
			time = animation_time
		})

		if not anim_info then return 'walk' end

		data.dancing_time = CurTime() + anim_info.time + 1
		return state, data
	end,
	update = function(actor, state, data)
		if data.dancing_time > CurTime() then return end
		actor:SetState('walk')
	end,
	not_stop = function(actor, state, data)
		return data.dancing_time > CurTime()
	end
})