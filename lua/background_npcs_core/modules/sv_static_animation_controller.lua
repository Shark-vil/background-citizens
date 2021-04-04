-- hook.Add("Think", "BGN_ActorAnimationController", function()

timer.Create('BGN_ActorAnimationController', 0.1, 0, function()
	local actors = bgNPC:GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if actor:IsAlive() then
			if actor:IsAnimationPlayed() then
				local npc = actor:GetNPC()
				npc:SetNPCState(NPC_STATE_SCRIPT)
				npc:SetSchedule(SCHED_SLEEP)
				
				if actor:IsLoopSequence() then
					if actor:IsSequenceLoopFinished() then
						hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
						if not actor:PlayNextStaticSequence() then
							actor:ResetSequence()
						end
					elseif actor:IsSequenceFinished() then
						npc:ResetSequenceInfo()
						npc:SetSequence(npc:LookupSequence(actor.anim_name))
					end
				elseif actor:IsSequenceFinished() then
					hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
					if not actor:PlayNextStaticSequence() then
						actor:ResetSequence()
					end
				end
			end
		end
	end
end)