local IsValid = IsValid
--
bgNPC:SetStateAction('scenic_npc', 'other', {
	not_stop = function(actor, state, data, next_state, next_data)
		local is_not_stop = not actor:HasStateGroup(next_state, 'danger')
			and not actor:HasStateGroup(next_state, 'guarded')
			and actor:TargetsCount() == 0
			and actor:EnemiesCount() == 0

		if not is_not_stop and IsValid(data.scenic_ent) then
			data.scenic_ent:Remove()
		end

		return IsValid(data.scenic_ent) and is_not_stop
	end
})