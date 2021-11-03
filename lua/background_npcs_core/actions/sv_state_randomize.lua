timer.Create('BGN_Timer_StateRandomize', bgNPC.cfg.RandomStateAssignmentPeriod, 0, function()
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor:IsAlive() then
			actor:RandomState()
		end
	end
end)

timer.Create('BGN_Timer_StateRandomizeReplics', 10, 0, function()
	if not GetConVar('bgn_module_replics_enable'):GetBool() then return end

	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor:IsAlive() and not actor:InVehicle() and slib.chance(30) then
			local data = actor:GetData()
			if not data or not data.replics then continue end

			if data.replics.state_names then
				for state_name, replics_id in pairs(data.replics.state_names) do
					if bgNPC.cfg.replics[replics_id] and actor:HasState(state_name) then
						actor:Say(table.RandomBySeq(bgNPC.cfg.replics[replics_id]))
						hook.Run('BGN_StartReplic', actor, replics_id)
						continue
					end
				end
			end

			if data.replics.state_groups then
				for group_name, replics_id in pairs(data.replics.state_groups) do
					if bgNPC.cfg.replics[replics_id] and actor:EqualStateGroup(group_name) then
						actor:Say(table.RandomBySeq(bgNPC.cfg.replics[replics_id]))
						hook.Run('BGN_StartReplic', actor, replics_id)
						continue
					end
				end
			end
		end
	end
end)