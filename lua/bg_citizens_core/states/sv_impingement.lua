timer.Create('bgCitizens_GangstersAssassination', 3, 0, function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        local data = actor:GetData()
        if not data.attack or math.random(0, 100) > data.chance_of_attack then
            goto skip
        end

        if not data.attack then
            goto skip
        end

        if IsValid(npc) and actor:GetState() ~= 'attacked' then
            local target_from_zone = ents.FindInSphere(npc:GetPos(), 500)
            local targets = {}

            for _, ent in pairs(target_from_zone) do
                if not IsValid(ent) or npc:Disposition(ent) == D_LI then
                    break
                end

                if ent:IsPlayer() and data.attack_player then
                    table.insert(targets, ent)
                end

                if ent:IsNPC() and ent ~= npc then
                    local zActor = bgCitizens:GetActor(ent)
                    if zActor ~= nil then
                        if data.attack_ignore ~= nil then
                            if table.HasValue(data.attack_ignore, zActor:GetType()) then
                                break
                            end
                        end
                        
                        table.insert(targets, ent)
                    end
                end
            end

            local target = table.Random(targets)
            if IsValid(target) then
                actor:SetState('attacked', {
                    target = target,
                    delay = 0,
                    old_relationship = npc:Disposition(target),
                })
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
            local stData = actor:GetStateData()

            if state == 'attacked' and IsValid(stData.target) then
                bgCitizens:SetActorWeapon(actor)

                if npc:Disposition(stData.target) ~= D_HT then
                    npc:AddEntityRelationship(stData.target, D_HT, 99)
                end

                if npc:GetTarget() ~= stData.target then
                    npc:SetTarget(stData.target)
                end
            elseif state == 'attacked' and not IsValid(stData.target) then
                actor:SetDefaultState()
            end
        end
    end
end)