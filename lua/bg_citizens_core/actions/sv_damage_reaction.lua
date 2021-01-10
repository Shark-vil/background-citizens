hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', 
function(attacker, target, dmginfo)
    local ActorTarget = bgNPC:GetActor(target)
    local ActorAttacker = bgNPC:GetActor(attacker)

    for _, actor in ipairs(bgNPC:GetAllByRadius(target:GetPos(), 2500)) do
        local reaction = actor:GetReactionForProtect()

        if actor == ActorTarget then
            goto skip
        end

        hook.Run('BGN_DamageToAnotherActor', actor, attacker, target, reaction)

        local hook_result = hook.Run('BGN_DamageToAnotherActor', actor, attacker, target, reaction) 
        if hook_result ~= nil then
            if isbool(hook_result) and not hook_result then
                goto skip
            end

            if isstring(hook_result) then
                reaction = hook_result
            end
        end

        local state = actor:GetState()
        if state == 'idle' or state == 'walk' or state == 'arrest' then
            actor:SetState(reaction)
        end

        ::skip::
    end
end)

hook.Add("BGN_DamageToAnotherActor", "BGN_AddActorsTargetByProtectOrFearActions", 
function(actor, attacker, target, reaction)
    if target:IsNPC() then
        local ActorTarget = bgNPC:GetActor(target)
        if ActorTarget ~= nil then
            if actor:HasTeam(ActorTarget) then
                actor:AddTarget(attacker)
                return
            end

            if actor:HasTeam('police') then
                if target:Disposition(attacker) ~= D_HT or bgNPC:IsEnemyTeam(attacker, 'residents') then
                    actor:AddTarget(attacker)
                elseif not actor:HasTarget(attacker) then
                    actor:AddTarget(target)
                end
            end
        end
    end

    if target:IsPlayer() then
        if actor:HasTeam('player') then
            actor:AddTarget(attacker)
            return
        end

        local ActorAttacker = bgNPC:GetActor(attacker)
        if ActorAttacker ~= nil then
            if actor:HasTeam(ActorAttacker) then
                actor:AddTarget(target)
                return
            end
        else
            if actor:HasTeam('residents') then
                actor:AddTarget(attacker)
            end
        end
    end
end)