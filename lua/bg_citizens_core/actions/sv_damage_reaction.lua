hook.Add('bgCitizens_TakeDamageReaction', 'bgCitizensAttackedOtherNPCAction', 
function(attacker, target, dmginfo)
    local ActorTarget = bgCitizens:GetActor(target)
    local ActorAttacker = bgCitizens:GetActor(attacker)

    for _, actor in ipairs(bgCitizens:GetAllByRadius(target:GetPos(), 2000)) do
        local reaction = actor:GetReactionForProtect()
        local targetFromActor = NULL

        if actor == ActorTarget then
            goto skip
        end

        if reaction == 'ignore' then
            goto skip
        end

        local state = actor:GetState()
        if state == 'fear' or state == 'defense' or state == 'calling_police' then
            goto skip
        end

        if target:IsNPC() then
            if attacker:IsPlayer() then
                if actor:GetType() == 'police' then
                    if bgCitizens:IsEnemyTeam(target, 'residents') then
                        targetFromActor = target
                    else
                        targetFromActor = attacker
                    end
                elseif target:Disposition(attacker) ~= D_HT then
                    targetFromActor = attacker
                end
            elseif attacker:IsNPC() then
                if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker) then
                    targetFromActor = target
                else
                    targetFromActor = attacker
                end
            end
        elseif target:IsPlayer() then
            if attacker:IsNPC() and attacker:Disposition(target) == D_HT then
                if ActorAttacker ~= nil then
                    if actor:HasTeam(ActorAttacker) then
                        targetFromActor = target
                    else
                        targetFromActor = attacker
                    end
                else
                    targetFromActor = attacker
                end
            end
        end

        if IsValid(targetFromActor) then
            if hook.Run('bgCitizens_ProtectReaction', actor, attacker, target) ~= nil then
                goto skip
            end

            actor:AddTarget(targetFromActor)
            actor:SetState(reaction, {
                delay = 0
            })
        end

        ::skip::
    end
end)