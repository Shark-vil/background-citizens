hook.Add('Think', 'bgCitizens_StateFearAction', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            if state == 'fear' and actor:TargetsCount() ~= 0  then
                if data.delay < CurTime() then
                    for _, target in ipairs(actor.targets) do
                        if npc:Disposition(target) ~= D_FR then
                            npc:AddEntityRelationship(target, D_FR, 99)
                            local ActorTarget = bgCitizens:GetActor(target)
                            if ActorTarget ~= nil then
                                ActorTarget:AddTarget(npc)
                                target:AddEntityRelationship(target, D_HT, 99)
                            end
                        end
                    end

                    actor:ClearSchedule()

                    if math.random(0, 10) <= 1 then
                        data.schedule = 'fear'
                    else
                        data.schedule = 'run'
                        data.update_run = 0
                    end

                    data.delay = CurTime() + 10
                end

                if data.schedule == 'run' and math.random(0, 100) == 0 then
                    for _, target in ipairs(actor.targets) do
                        if npc:GetPos():Distance(target:GetPos()) < 150 then
                            data.schedule = 'fear'
                            break
                        end
                    end
                end
                
                if data.schedule == 'fear' then
                    npc:ClearSchedule()
                    npc:SetSchedule(SCHED_NONE)
                    npc:SetSequence(npc:LookupSequence('Fear_Reaction_Idle'))
                elseif data.schedule == 'run' and data.update_run < CurTime() then
                    npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
                    data.update_run = CurTime() + 3
                end
            end
        end
    end
end)