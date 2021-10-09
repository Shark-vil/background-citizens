timer.Create('BGN_Timer_StateRandomize', bgNPC.cfg.RandomStateAssignmentPeriod, 0, function()
	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor:IsAlive() then
			actor:RandomState()
		end
	end
end)
