--

-- timer.Create('BGN_ActorAnimationController', .1, 0, function()

hook.Add('Think', 'BGN_ActorAnimationController', function()
	local actors = bgNPC.Actors.GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		local npc = actor:GetNPC()
		if actor and actor:IsAlive() and actor:IsAnimationPlayed() then
			-- re-setting the schedule or the sequence every tick restarts it: the NPC flickers between frames
			if isfunction(npc.SetSchedule) and not npc:IsCurrentSchedule(SCHED_SLEEP) then
				npc:SetNPCState(NPC_STATE_SCRIPT)
				npc:SetSchedule(SCHED_SLEEP)
			end

			if actor:IsLoopSequence() then
				if actor:IsSequenceLoopFinished() then
					hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
					if not actor:PlayNextStaticSequence() then
						actor:ResetSequence()
					end
				elseif isnumber(actor.anim_sequence) and (npc:GetSequence() ~= actor.anim_sequence or npc:GetCycle() >= 0.98) then
					npc:ResetSequence(actor.anim_sequence) -- taken by the engine, or a one-shot sequence ended: again
					npc:SetCycle(0)
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