hook.Add('EntityTakeDamage', 'BGN_ActorTakeDamageEvent', function(target, dmginfo)
    if not target:IsPlayer() and not target:IsNPC() then return end

    local attacker = dmginfo:GetAttacker()
    if not attacker:IsPlayer() and not attacker:IsNPC() then return end

    local ActorTarget = bgNPC:GetActor(target)
    local ActorAttacker = bgNPC:GetActor(attacker)

    if target:IsNPC() then
        if ActorTarget == nil then
            return
        else
            if attacker:IsPlayer() then
                if ActorTarget:HasTeam('player') then
                    return true
                elseif bgNPC:GetEntityVariable(attacker, 'is_wanted', false) then
                    bgNPC:SetEntityVariable(attacker, 'wanted_time_reset', CurTime() + bgNPC.wanted_time)
                    bgNPC:SetEntityVariable(attacker, 'wanted_time', bgNPC.wanted_time)
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

        local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, dmginfo)
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

        hook.Run('BGN_PostReactionTakeDamage', attacker, target, dmginfo)
    elseif target:IsPlayer() then
        if attacker:IsNPC() and ActorAttacker ~= nil then
            if bgNPC:GetEntityVariable(attacker, 'is_wanted', false) then
                bgNPC:SetEntityVariable(attacker, 'wanted_time_reset', CurTime() + bgNPC.wanted_time)
                bgNPC:SetEntityVariable(attacker, 'wanted_time', bgNPC.wanted_time)
            end

            if ActorAttacker:HasTeam('player') then
                return
            end

            local hook_result = hook.Run('BGN_PreReactionTakeDamage', attacker, target, dmginfo)
            if hook_result ~= nil then
                if isbool(hook_result) then
                    return hook_result
                end
            end

            hook.Run('BGN_PostReactionTakeDamage', attacker, target, dmginfo)
        end
    end
end)