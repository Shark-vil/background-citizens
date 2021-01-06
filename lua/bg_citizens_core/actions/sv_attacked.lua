hook.Add("OnNPCKilled", "bgCitizens_OnNPCKilled", function(npc, attacker, inflictor)
    local actor = bgCitizens:GetActor(npc)
    if actor ~= nil then
        hook.Run('bgCitizens_OnKilledActor', actor, attacker)
    end
end)

hook.Add("bgCitizens_OnKilledActor", "bgCitizens_AutoLargeMurderWanted", function(actor, attacker)
    if attacker:IsPlayer() then
        local count = bgCitizens:AddKillingStatistic(attacker, actor)
        if not attacker:GetNWBool('bgCitizenWanted') and actor:GetType() == 'police' and count > 3 then
            table.insert(bgCitizens.wanted, attacker)
            attacker.bgCitizenWantedReset = CurTime() + 30
            attacker:SetNWBool('bgCitizenWanted', true)
        end
    end
end)

hook.Add("PlayerDeath", "bgCitizens_PlayerDeathRemoveTargets", function(victim, inflictor, attacker)
    bgCitizens.killing_statistic[victim] = {}
    for _, actor in ipairs(bgCitizens:GetAll()) do
        actor:RemoveTarget(victim)
    end
end)

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
            if isbool(hook_result) then return hook_result end
            return
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

timer.Create('bgCitizens_ActorsFriendServices', 1, 0, function()
    local actors = bgCitizens:GetAll()

    for _, ActorOne in ipairs(actors) do
        local npc_1 = ActorOne:GetNPC()
        for _, ActorTwo in ipairs(actors) do
            if ActorOne ~= ActorTwo then
                local npc_2 = ActorTwo:GetNPC()

                if IsValid(npc_1) and IsValid(npc_2) then
                    if ActorOne:HasTeam(ActorTwo) then
                        if npc_1:Disposition(npc_2) ~= D_NU or npc_2:Disposition(npc_1) ~= D_NU then
                            npc_1:AddEntityRelationship(npc_2, D_NU, 99)
                            npc_2:AddEntityRelationship(npc_1, D_NU, 99)
                        end
                    end
                end
            end
        end
    end
end)

timer.Create('bgCitizens_ResetAttackedEvent', 0.5, 0, function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
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

                    -- if actor:GetType() == 'police' then
                    --     npc:Give('weapon_stunstick')
                    --     npc:SelectWeapon('weapon_stunstick')
                    -- end

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

hook.Remove('Think', 'bgCitizens_ResetAttackedEvent')