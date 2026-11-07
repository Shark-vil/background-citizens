--

-- timer.Create('BGN_ActorAnimationController', .1, 0, function()

hook.Add('Think', 'BGN_ActorAnimationController', function()
	local actors = bgNPC.Actors.GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if actor and actor:IsAlive() and actor:IsAnimationPlayed() then
			if isfunction(npc.SetNPCState) then
				npc:SetNPCState(NPC_STATE_SCRIPT)
			end

			if isfunction(npc.SetSchedule) then
				npc:SetSchedule(SCHED_SLEEP)
			end

			if actor:IsLoopSequence() then
				if actor:IsSequenceLoopFinished() then
					hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
					if not actor:PlayNextStaticSequence() then
						actor:ResetSequence()
					end
				elseif isnumber(actor.anim_sequence) then
					npc:ResetSequence(actor.anim_sequence)
				end
			elseif actor:IsSequenceFinished() then
				hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
				if not actor:PlayNextStaticSequence() then
					actor:ResetSequence()
				end
			end
		end
	end
end)