hook.Add("OnNPCKilled", "bgCitizens_OnNPCKilled", function(npc, attacker, inflictor)
    local actor = bgCitizens:GetActor(npc)
    if actor ~= nil then
        hook.Run('bgCitizens_OnKilledActor', actor, attacker, inflictor)
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
            if attacker:IsPlayer() and ActorTarget:HasTeam('player') then
                return
            elseif attacker:IsNPC() and ActorAttacker ~= nil then
                if ActorTarget:HasTeam(ActorAttacker:GetData().team) then
                    ActorTarget:RemoveTarget(attacker)
                    ActorAttacker:RemoveTarget(target)

                    attacker:AddEntityRelationship(target, D_NU, 99)
                    target:AddEntityRelationship(attacker, D_NU, 99)
                    return
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

        if state ~= 'fear' and state ~= 'defense'then
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

    for _, actor in ipairs(bgCitizens:GetAllByRadius(target:GetPos(), 2000)) do
        local reaction = actor:GetReactionForProtect()
        local targetFromActor = NULL

        if reaction == 'ignore' then
            goto skip
        end

        local state = actor:GetState()
        if state == 'fear' or state == 'defense' then
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
                if ActorAttacker ~= nil and actor:HasTeam(ActorAttacker:GetData().team) then
                    targetFromActor = target
                else
                    targetFromActor = attacker
                end
            end
        elseif target:IsPlayer() then
            if attacker:IsNPC() and attacker:Disposition(target) == D_HT then
                if ActorAttacker ~= nil then
                    if actor:HasTeam(ActorAttacker:GetData().team) then
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

timer.Create('bgCitizens_ActorsFriendServices', 5, 0, function()
    local actors = bgCitizens:GetAll()
    for _, ActorOne in ipairs(actors) do
        local state_1 = ActorOne:GetState()
        local npc_1 = ActorOne:GetNPC()

        for _, ActorTwo in ipairs(actors) do
            local state_2 = ActorTwo:GetState()

            if ActorOne ~= ActorTwo 
                and (state_1 ~= 'defense' and state_1 ~= 'fear')
                and (state_2 ~= 'defense' and state_2 ~= 'fear')
            then
                local npc_2 = ActorTwo:GetNPC()

                if IsValid(npc_1) and IsValid(npc_2) then
                    if ActorOne:HasTeam(ActorTwo:GetData().team) then
                        if npc_1:Disposition(npc_2) ~= D_LI or npc_2:Disposition(npc_1) ~= D_LI then
                            npc_1:AddEntityRelationship(npc_2, D_LI, 99)
                            npc_2:AddEntityRelationship(npc_1, D_LI, 99)
                        end
                    else
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

hook.Add('Think', 'bgCitizens_ResetAttackedEvent', function()
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