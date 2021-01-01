local function SetReaction(actor, attacker, victim)
    local state = actor:GetState()

    if state == 'fear' or state == 'defense' then
        for _, stData in pairs(actor:GetStateData()) do
            if stData.target == attacker then
                return
            end
        end

        table.insert(actor:GetStateData(), {
            target = attacker,
            old_relationship = actor:GetNPC():Disposition(attacker),
            delay = 0
        })
        return
    end

    local data = actor:GetData()

    if data.at_damage ~= nil then
        if actor:GetNPC() ~= victim and data.protect then
            if victim:IsNPC() then
                local vActor = bgCitizens:GetActor(victim)
                if table.HasValue(data.protect_ignore, vActor:GetType()) then
                    return
                end
            elseif victim:IsPlayer() then
                if table.HasValue(data.protect_ignore, 'player') then
                    return
                end
            end
        end

        local probability = math.random(1, 100)
        local percent, reaction

        if actor:GetNPC() == victim then
            percent, reaction = table.Random(data.at_damage)
        else
            percent, reaction = table.Random(data.at_protect)
        end

        if probability > percent then
            local last_percent = 0
            
            for _reaction, _percent in pairs(data.at_damage) do
                if _percent > last_percent then
                    percent = _percent
                    reaction = _reaction
                    last_percent = percent
                end
            end
        end

        if reaction ~= 'ignore' then
            actor:SetState(reaction, {
                {
                    target = attacker,
                    old_relationship = actor:GetNPC():Disposition(attacker),
                    delay = 0
                }
            })

            if reaction == 'fear' and math.random(0, 10) <= 1 then
                actor:GetNPC():EmitSound(table.Random({
                    'ambient/voices/f_scream1.wav',
                    'ambient/voices/m_scream1.wav',
                    'vo/canals/arrest_helpme.wav',
                    'vo/coast/bugbait/sandy_help.wav',
                    'vo/npc/female01/help01.wav',
                    'vo/npc/male01/help01.wav',
                    'vo/Streetwar/sniper/male01/c17_09_help01.wav',
                    'vo/Streetwar/sniper/male01/c17_09_help02.wav'
                }), 500, 100, 1, CHAN_AUTO)
            end
        end
    end
end

hook.Add('EntityTakeDamage', 'bgCitizensAttackedNPCAction', function(target, dmginfo)
    if IsValid(target) and target:Health() > 0 then
        local attacker = dmginfo:GetAttacker()
        local aActor = bgCitizens:GetActor(attacker)

        if target:IsNPC() and not bgCitizens:HasNPC(target) then
            return
        end

        if (attacker:IsNPC() and attacker:Disposition(target) == D_HT) 
            or (attacker:IsPlayer() and target:Disposition(attacker) ~= D_HT)
            or (aActor ~= nil and aActor:GetType() == 'attacked')
        then
            if bgCitizens:IsTeamOnce(attacker, target) then
                return
            end

            do
                if target:IsNPC() then
                    local actor = bgCitizens:GetActor(target)
                    if actor == nil then return end

                    SetReaction(actor, attacker, target)
                end
            end

            local entities = ents.FindInSphere(target:GetPos(), 2000)
            for _, npc in pairs(entities) do
                if IsValid(npc) and target ~= npc and bgCitizens:HasNPC(npc) then
                    local actor = bgCitizens:GetActor(npc)
                    local state = actor:GetState()
                    if state == 'defense' or state == 'fear' or state == 'attacked' then
                        goto skip
                    end

                    if npc:GetPos():Distance(attacker:GetPos()) > 1000 then
                        local tr = util.TraceLine({
                            start = npc:EyePos(),
                            endpos = attacker:EyePos(),
                            filter = function(ent) 
                                if ent ~= npc then
                                    return true
                                end
                            end
                        })

                        if not tr.Hit or (IsValid(tr.Entity) and tr.Entity ~= attacker) then
                            goto skip
                        end
                    end

                    if hook.Run('bgCitizens_PreReactionToAttack', npc, target, dmginfo) ~= nil then
                        goto skip
                    end

                    SetReaction(actor, attacker, target)

                    ::skip::
                end
            end
        end
    end
end)

hook.Add('Think', 'bgCitizens_ResetAttackedEvent', function()
    for _, actor in pairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()

            if state == 'defense' or state == 'fear' then
                local allDeath = true
                for _, stData in pairs(actor:GetStateData()) do
                    if IsValid(stData.target) and stData.target:Health() >= 0 then
                        allDeath = false
                        break
                    end
                end

                if allDeath then
                    for _, stData in pairs(actor:GetStateData()) do
                        if IsValid(stData.target) then
                            npc:AddEntityRelationship(stData.target, stData.old_relationship, 99)
                        end
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