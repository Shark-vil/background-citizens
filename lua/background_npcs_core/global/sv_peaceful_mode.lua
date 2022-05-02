function bgNPC:IsPeacefulMode()
	return GetConVar('bgn_peaceful_mode'):GetBool()
end

hook.Add('BGN_PreSetState', 'BGN_Peaceful_Mode', function(actor, state, data)
	if not bgNPC:IsPeacefulMode() then return end

	local state_group = bgNPC:GetStateGroupName(state)
	if state_group == 'danger' or state_group == 'guarded' then
		return {
			state = 'walk',
			data = {}
		}
	end
end)