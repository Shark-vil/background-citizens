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
            if attacker:IsPlayer() then
                if ActorTarget:HasTeam('player') then
                    return true
                elseif attacker:GetNWBool('bgCitizenWanted') then
                    attacker.bgCitizenWantedReset = CurTime() + 30
                end
            elseif attacker:IsNPC() and ActorAttacker ~= nil then
                if ActorTarget:HasTeam(ActorAttacker) then
                    ActorTarget:RemoveTarget(attacker)
                    ActorAttacker:RemoveTarget(target)

                    attacker:AddEntityRelationship(target, D_NU, 99)
                    target:AddEntityRelationship(attacker, D_NU, 99)
                    return true
                end
            end
        end

        local hook_result = hook.Run('bgCitizens_TakeDamageReaction', attacker, target, dmginfo)
        if hook_result ~= nil then
            if isbool(hook_result) then
                return hook_result
            end
        end

        local state = ActorTarget:GetState()
        ActorTarget:AddTarget(attacker)

        if state ~= 'fear' and state ~= 'defense' and state ~= 'calling_police' then
            local reaction = ActorTarget:GetReactionForDamage()
            ActorTarget:SetState(reaction, {
                delay = 0
            })
        end
    elseif target:IsPlayer() then
        if attacker:IsNPC() and ActorAttacker ~= nil then
            if target:GetNWBool('bgCitizenWanted') then
                target.bgCitizenWantedReset = CurTime() + 30
            end

            if ActorAttacker:HasTeam('player') then
                return
            end
        end
    end
end)