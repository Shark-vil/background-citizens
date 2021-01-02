hook.Add('EntityTakeDamage', 'bgCitizensAttackedNPCAction', function(target, dmginfo)
    if not target:IsPlayer() and not target:IsNPC() then return end

    local attacker = dmginfo:GetAttacker()
    if not attacker:IsPlayer() and not attacker:IsNPC() then return end

    local ActorTarget = bgCitizens:GetActor(target)
    local ActorAttacker = bgCitizens:GetActor(attacker)

    if target:IsNPC() then
        if ActorTarget == nil then
            return
        else
            if attacker:IsPlayer() and ActorTarget:HasTeam('player') then
                return true
            elseif attacker:IsNPC() and ActorAttacker ~= nil then
                if ActorTarget:HasTeam(ActorAttacker:GetData().team) then
                    return true
                end
            end
        end

        if hook.Run('bgCitizens_TakeDamageReaction', attacker, target, dmginfo) ~= nil then
            return
        end

        local state = ActorTarget:GetState()
        ActorTarget:AddTarget(attacker)

        if state ~= 'fear' and state ~= 'defense' and state ~= 'attacked' then
            local reaction = ActorTarget:GetReactionForDamage()
            ActorTarget:SetState(reaction, {
                delay = 0
            })
        end
    elseif target:IsPlayer() then
        if attacker:IsNPC() and ActorAttacker ~= nil then
            if ActorAttacker:HasTeam('player') then
                return true
            end
        end
    end

    for _, actor in pairs(bgCitizens:GetAllByRadius(target:GetPos(), 2000)) do
        local reaction = actor:GetReactionForProtect()
        local targetFromActor = NULL

        if reaction == 'ignore' then
            goto skip
        end

        local state = actor:GetState()
        if state == 'fear' or state == 'defense' or state == 'attacked' then
            goto skip
        end

        if target:IsNPC() then
            if attacker:IsPlayer() and target:Disposition(attacker) ~= D_HT then
                if actor:GetType() == 'police' and target:Disposition(attacker) ~= D_HT then
                    targetFromActor = attacker
                elseif actor:HasTeam(ActorTarget:GetData().team) then
                    targetFromActor = attacker
                end
            elseif attacker:IsNPC() then
                if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker:GetData().team) then
                    targetFromActor = target
                else
                    targetFromActor = attacker
                end
            end
        elseif target:IsPlayer() then
            if attacker:IsNPC() then
                if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker:GetData().team) then
                    targetFromActor = target
                end
            end
        end

        if IsValid(targetFromActor) then
            if hook.Run('bgCitizens_ProtectReaction', actor, attacker, target, dmginfo) ~= nil then
                goto skip
            end

            actor:AddTarget(targetFromActor)
            actor:SetState(reaction, {
                delay = 0
            })

            -- print(actor:GetType() .. ' -> ' .. reaction)
            -- print('{')
            -- PrintTable(actor.targets)
            -- print('}')
        end

        ::skip::
    end
end)

hook.Add('Think', 'bgCitizens_ResetAttackedEvent', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()

            if state == 'defense' or state == 'fear' then
                actor:RecalculationTargets()

                if actor:TargetsCount() == 0 then        
                    local wep = npc:GetActiveWeapon()
                    if IsValid(wep) then
                        wep:Remove()
                    end

                    actor:SetState('walk', {
                        schedule = SCHED_FORCED_GO,
                        runReset = 0
                    })

                    goto skip
                end
            end
        end

        ::skip::
    end
end)