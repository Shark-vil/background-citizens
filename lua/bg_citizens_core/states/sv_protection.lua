hook.Add('Think', 'bgCitizens_StateProtectionAction', function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            actor:RecalculationTargets()

            if state == 'defense' and actor:TargetsCount() ~= 0  then
                bgCitizens:SetActorWeapon(actor)

                for _, target in ipairs(actor.targets) do
                    if npc:Disposition(target) ~= D_HT then
                        npc:AddEntityRelationship(target, D_HT, 99)
                    end
                end

                if data.delay < CurTime() then
                    local target = table.Random(actor.targets)
                    if IsValid(target) then
                        local point = nil
                        local current_distance = npc:GetPos():DistToSqr(target:GetPos())

                        if current_distance >= 500000 then -- 500 * 1000
                            if math.random(0, 10) > 4 then
                                point = actor:GetMovementPointToTarget(target:GetPos())
                            else
                                point = target:GetPos()
                            end
                        elseif current_distance < 500000 and current_distance > 200000 then
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