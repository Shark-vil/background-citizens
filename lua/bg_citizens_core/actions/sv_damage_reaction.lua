local function IsTargetRay(watcher, ent)
    if not IsValid(ent) then return false end
    local center_pos = LocalToWorld(ent:OBBCenter(), Angle(), ent:GetPos(), Angle())

    local tr = util.TraceLine({
        start = watcher:EyePos(),
        endpos = center_pos,
        filter = function(e)
            if e ~= watcher then
                return true
            end
        end
    })

    if not tr.Hit or tr.Entity ~= ent then
        return false
    end

    return true
end

hook.Add('BGN_PostReactionTakeDamage', 'BGN_ActorsReactionToDamageAnotherActor', 
function(attacker, target, dmginfo)
    for _, actor in ipairs(bgNPC:GetAllByRadius(target:GetPos(), 2500)) do
        local reaction = actor:GetReactionForProtect()
        actor:SetReaction(reaction)

        local npc = actor:GetNPC()
        if npc == target then
            goto skip
        end

        if not IsTargetRay(npc, attacker) and not IsTargetRay(npc, target) then
            goto skip
        end

        local hook_result = hook.Run('BGN_PreDamageToAnotherActor', actor, attacker, target, reaction) 
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
            actor:SetState(actor:GetLastReaction())
        end

        hook.Run('BGN_PostDamageToAnotherActor', actor, attacker, target, reaction)

        ::skip::
    end
end)

hook.Add("BGN_PostDamageToAnotherActor", "BGN_AddActorsTargetByProtectOrFearActions", 
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
    elseif target:IsPlayer() then
        if actor:HasTeam('player') then
            actor:AddTarget(attacker)
            return
        end

        local ActorAttacker = bgNPC:GetActor(attacker)
        if ActorAttacker ~= nil then
            local team = ActorAttacker:GetData().team
            if actor:HasTeam(ActorAttacker) and bgNPC:IsEnemyTeams(target, team) then
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