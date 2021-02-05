hook.Add("Think", "BGN_ActorAnimationController", function()
	for _, actor in ipairs(bgNPC:GetAll()) do
		local npc = actor:GetNPC()
		if IsValid(npc) then
			if actor:IsAnimationPlayed() then
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