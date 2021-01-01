hook.Add('Think', 'bgCitizens_StateFearAction', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()

            for _, stData in pairs(actor:GetStateData()) do
                if state == 'fear' and IsValid(stData.target) then
                    if stData.delay < CurTime() then
                        if npc:Disposition(stData.target) ~= D_FR then
                            npc:AddEntityRelationship(stData.target, D_FR, 99)
                        end

                        actor:ClearSchedule()

                        if math.random(0, 10) <= 1 then
                            stData.schedule = 'fear'
                        else
                            stData.schedule = 'run'
                            stData.update_run = 0
                        end

                        stData.delay = CurTime() + 10
                    end

                    if stData.schedule == 'run'
                        and npc:GetPos():Distance(stData.target:GetPos()) < 150 
                        and math.random(0, 100) == 0
                    then
                        stData.schedule = 'fear'
                    end
                    
                    if stData.schedule == 'fear' then
                        npc:ClearSchedule()
                        npc:SetSchedule(SCHED_NONE)
                        npc:SetSequence(npc:LookupSequence('Fear_Reaction_Idle'))
                    elseif stData.schedule == 'run' and stData.update_run < CurTime() then
                        npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
                        stData.update_run = CurTime() + 3
                    end
                end
            end
        end
    end
end)