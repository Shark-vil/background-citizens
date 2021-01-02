hook.Add('Think', 'bgCitizens_StateProtectionAction', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            actor:RecalculationTargets()

            if state == 'defense' and actor:TargetsCount() ~= 0  then
                bgCitizens:SetActorWeapon(actor)

                for _, target in pairs(actor.targets) do
                    if npc:Disposition(target) ~= D_HT then
                        npc:AddEntityRelationship(target, D_HT, 99)
                    end
                end

                if data.delay < CurTime() then
                    local target = table.Random(actor.targets)
                    if IsValid(target) then
                        local point = nil
                        local current_distance = npc:GetPos():Distance(target:GetPos())

                        if current_distance >= 500 then
                            if math.random(0, 10) > 4 then
                                point = actor:GetMovementPointToTarget(target:GetPos())
                            else
                                point = target:GetPos()
                            end
                        elseif current_distance < 500 and current_distance > 200 then
                            point = target:GetPos()
                        end

                        if point ~= nil then
                            npc:SetSaveValue("m_vecLastPosition", point)
                            npc:SetSchedule(SCHED_FORCED_GO_RUN)
                            -- print('police move to ' .. tostring(point))
                        end
                        data.delay = CurTime() + 3
                    end
                end
            end
        end
    end
end)