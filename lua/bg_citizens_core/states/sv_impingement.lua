timer.Create('bgCitizens_GangstersAssassination', 5, 0, function()
    for _, actor in pairs(bgCitizens:GetAllByType('gangster')) do
        local npc = actor:GetNPC()

        if math.random(0, 100) > 10 then
            goto skip
        end

        if IsValid(npc) and actor:GetState() ~= 'attacked' then
            local target_from_zone = ents.FindInSphere(npc:GetPos(), 500)
            local targets = {}

            for _, ent in pairs(target_from_zone) do
                if ent:IsPlayer() then
                    table.insert(targets, ent)
                end

                if ent:IsNPC() and ent ~= npc then
                    local ActorTarget = bgCitizens:GetActor(ent)
                    if ActorTarget ~= nil and not actor:HasTeam(ActorTarget:GetData().team) then
                        table.insert(targets, ent)
                    end
                end
            end

            local target = table.Random(targets)
            if IsValid(target) then
                actor:AddTarget(target)
                actor:SetState('attacked', {
                    delay = 0
                })
                break
            end
        end

        ::skip::
    end
end)


hook.Add('Think', 'bgCitizens_StateAttackAction', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            for _, target in pairs(actor.targets) do
                if state == 'attacked' then
                    bgCitizens:SetActorWeapon(actor)

                    if npc:Disposition(target) ~= D_HT then
                        npc:AddEntityRelationship(target, D_HT, 99)
                    end

                    if npc:GetTarget() ~= target then
                        npc:SetTarget(target)
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
                                -- print('gangster move to ' .. tostring(point))
                            end
                            data.delay = CurTime() + 3
                        end
                    end
                elseif state == 'attacked' and not IsValid(target) then
                    local wep = npc:GetActiveWeapon()
                    if IsValid(wep) then
                        wep:Remove()
                    end
                    
                    actor:SetDefaultState()
                end
            end
        end
    end
end)