hook.Add("Think", "bgCitizensLoopAnimatorController", function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            if actor:IsAnimationPlayed() then
                npc:SetNPCState(NPC_STATE_SCRIPT)
                npc:SetSchedule(SCHED_SLEEP)

                if actor:IsLoopSequence() then
                    if actor:IsSequenceLoopFinished() then
                        hook.Run('bgCitizen_FinishNPCAnimation', actor, actor.anim_name)
                        actor:ResetSequence()
                    elseif actor:IsSequenceFinished() then
                        npc:ResetSequenceInfo()
                        npc:SetSequence(npc:LookupSequence(actor.anim_name))
                    end
                elseif actor:IsSequenceFinished() then
                    hook.Run('bgCitizen_FinishNPCAnimation', actor, actor.anim_name)
                    actor:ResetSequence()
                end
            end
        end
    end
end)