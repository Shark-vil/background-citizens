timer.Create('BGN_Timer_ImpingementController', 5, 0, function()
    for _, actor in ipairs(bgCitizens:GetAllByType('gangster')) do
        local npc = actor:GetNPC()

        if math.random(0, 100) > 1 then
            goto skip
        end

        if IsValid(npc) and actor:GetState() ~= 'defense' then
            local target_from_zone = ents.FindInSphere(npc:GetPos(), 500)
            local targets = {}

            for _, ent in pairs(target_from_zone) do
                if ent:IsPlayer() then
                    table.insert(targets, ent)
                end

                if ent:IsNPC() and ent ~= npc then
                    local ActorTarget = bgCitizens:GetActor(ent)
                    if ActorTarget ~= nil and not actor:HasTeam(ActorTarget) then
                        table.insert(targets, ent)
                    end
                end
            end

            local target = table.Random(targets)
            if IsValid(target) then
                actor:AddTarget(target)
                actor:SetState('defense', {
                    delay = 0
                })
                break
            end
        end

        ::skip::
    end
end)