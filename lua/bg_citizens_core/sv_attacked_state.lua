local function GiveWeaponFromNPC(npc)
    local select_weapon = table.Random({'weapon_pistol', 'weapon_357'})
    local hook_weapon = hook.Run('bgCitizens_PreGiveWeapon', npc, select_weapon)
    if hook_weapon ~= nil and isstring(hook_weapon) then
        select_weapon = hook_weapon
    end

    local weapons = npc:GetWeapons()
    local isExist = false
    for _, weapon in pairs(weapons) do
        local weapon_class = weapon:GetClass()
        if weapon_class == select_weapon then
            isExist = true
            break
        end
    end

    if not isExist then
        npc:Give(select_weapon)
    end

    npc:SelectWeapon(select_weapon)
end

timer.Create('bgCitizens_AccidentalAttack', 30, 0, function()
    if math.random(0, 10) == 0 and bgCitizens.fnpcs['gangster'] ~= nil then
        local npc = table.Random(bgCitizens.fnpcs['gangster'])

        if IsValid(npc) then
            local target_from_zone = ents.FindInSphere(npc:GetPos(), 500)
            local targets = {}

            for _, ent in pairs(target_from_zone) do
                if ent:IsPlayer() or ent:IsNPC() and ent ~= npc then
                    if ent:IsNPC() and not table.HasValue(bgCitizens.npcs, ent) then
                        goto skip
                    end
                    table.insert(targets, ent)
                end

                ::skip::
            end

            local target = table.Random(targets)
            if IsValid(target) and npc:Disposition(target) ~= D_LI then
                npc:bgCitizenStateUpdate('attacked', {
                    target = target,
                    delay = 0,
                    oldDisposition = npc:Disposition(target),
                    isAttack = true
                })
            end
        end
    end
end)

hook.Add('EntityTakeDamage', 'bgCitizens_AttackedEvent', function(target, dmginfo)
    if IsValid(target) and target:Health() > 0 then
        local attacker = dmginfo:GetAttacker()
        local fearTarget = attacker

        -- if target:IsPlayer() and (attacker.bgCitizenType ~= 'gangster' 
        --     or attacker.bgCitizenType == 'police')
        -- then
        --     fearTarget = target
        -- end

        if attacker:IsPlayer() and 
            target.bgCitizenType == 'gangster' and target:Disposition(attacker) == D_HT
        then
            fearTarget = target
        end

        if attacker.bgCitizenType == 'police' then
            fearTarget = NULL
            if target:IsPlayer() or (target:IsNPC() and target:Disposition(attacker) == D_HT) then
                fearTarget = target
            end
        end
        
        local otherNPCs = ents.FindInSphere(target:GetPos(), 2000)
        for _, npc in pairs(otherNPCs) do
            if IsValid(npc) and table.HasValue(bgCitizens.npcs, npc) and npc:GetState() ~= 'attacked' then
                if npc ~= target then
                    if npc:GetPos():Distance(target:GetPos()) > 1000 then
                        local tr = util.TraceLine({
                            start = npc:EyePos(),
                            endpos = target:EyePos(),
                            filter = function(ent) 
                                if ent ~= npc then
                                    return true
                                end
                            end
                        })

                        if not tr.Hit and IsValid(tr.Entity) and tr.Entity == target then
                            goto skip
                        end
                    end
                end

                if hook.Run('bgCitizens_PreReactionToAttack', npc, target, dmginfo) ~= nil then
                    goto skip
                end
                
                npc:bgCitizenTaskClear()
                
                local state = npc:bgCitizenStateUpdate('attacked', {
                    target = fearTarget,
                    delay = 0,
                    oldDisposition = npc:Disposition(attacker)
                })

                if math.random(0, 100) == 0 or npc.bgCitizenType == 'police' 
                    or npc.bgCitizenType == 'gangster'
                then
                    state.data.isAttack = true
                end

                if math.random(0, 10) <= 1 then
                    npc:EmitSound(table.Random({
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

                hook.Run('bgCitizens_PostReactionToAttack', npc, target, dmginfo)

                ::skip::
            end
        end
    end
end)

hook.Add('bgCitizens_PreGiveWeapon', 'bgCitizens_GivePoliceWeapon', function(npc)
    if npc.bgCitizenType == 'police' then
        return table.Random({'weapon_smg1', 'weapon_pistol'})
    end
end)

hook.Add('Think', 'bgCitizens_AttackedEvent', function()
    for _, npc in pairs(bgCitizens.npcs) do
        if IsValid(npc) then
            local data = npc:GetStateData()
            
            if npc:GetState() == 'attacked' then
                if not IsValid(data.target) or data.target:Health() <= 0 then
                    if data.oldDisposition ~= nil and IsValid(data.target) then
                        npc:AddEntityRelationship(data.target, data.oldDisposition, 99)
                    end

                    npc:bgCitizenStateUpdate('walk', {
                        schedule = SCHED_FORCED_GO,
                        runReset = 0
                    })
                else
                    if data.isAttack and npc:Disposition(data.target) ~= D_HT then
                        GiveWeaponFromNPC(npc)

                        npc:AddEntityRelationship(data.target, D_HT, 99)
                        if npc:GetTarget() ~= data.target then
                            npc:SetTarget(data.target)
                        end
                    else
                        if data.delay < CurTime() then
                            if npc:Disposition(data.target) ~= D_FR then
                                npc:AddEntityRelationship(data.target, D_FR, 99)
                            end

                            npc:bgCitizenTaskClear()

                            if math.random(0, 10) <= 1 then
                                data.schedule = 'fear'
                            else
                                npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
                                data.schedule = 'run'
                            end

                            data.delay = CurTime() + 10
                        end

                        if not data.isAttack and data.schedule == 'fear' then
                            npc:SetSchedule(SCHED_NONE)
                            npc:ResetSequence(npc:LookupSequence('Fear_Reaction_Idle'))
                            npc:ResetSequenceInfo()
                            npc:SetCycle(0)
                        end
                    end
                end
            end
        end
    end
end)