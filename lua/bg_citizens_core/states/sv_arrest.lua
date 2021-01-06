local arrest_players = {}

hook.Add("bgCitizens_TakeDamageReaction", "EnableArrestModeFirstDamage", function(attacker, target, dmginfo)
    if not bgCitizens.arrest_moode then return end
    
    local ActorTarget = bgCitizens:GetActor(target)
    if attacker:IsPlayer() and ActorTarget ~= nil and ActorTarget:GetType() == 'citizen' then
        if arrest_players[attacker] ~= nil then 
            arrest_players[attacker].count = arrest_players[attacker].count + 1
            if arrest_players[attacker].delayIgnore > CurTime() and arrest_players[attacker].count >= 3 then
                arrest_players[attacker].delayIgnore = 0
            end
            return 
        end
        
        arrest_players[attacker] = {
            target = target,
            delay = CurTime() + 1.5,
            delayIgnore = CurTime() + bgCitizens.arrest_time_limit,
            count = 1
        }
    end
end)

hook.Add("bgCitizens_OnKilledActor", "ResetArrestModeIfKilledNPC", function(actor, attacker)
    if arrest_players[attacker] ~= nil then
        if arrest_players[attacker].target == actor:GetNPC() then
            arrest_players[attacker].delayIgnore = 0
        end
    end
end)

hook.Add("bgCitizens_ProtectReaction", "EnableArrestModeFirstDamage", function(actor, attacker, target)
    if not IsValid(attacker) or not IsValid(target) then
        return
    end

    if arrest_players == nil or arrest_players[attacker] == nil 
        or arrest_players[attacker].target == nil or not IsValid(arrest_players[attacker].target)
    then
        return
    end

    if arrest_players[attacker].arrest ~= nil and not arrest_players[attacker].arrest then
        return
    end

    if actor:GetType() == 'police' then
        if actor:GetReactionForProtect() ~= 'arrest' then
            arrest_players[attacker].arrest = false
            return
        end
    else
        if arrest_players[attacker].delay > CurTime() then
            return true
        end
    end

    arrest_players[attacker].arrest = true
    
    if arrest_players[attacker].target == target then
        arrest_players[attacker].notify_delay = arrest_players[attacker].notify_delay or 0
        actor:SetState('arrest', {
            targets = target,
            attacker = attacker,
        })
        return true
    end
end)

timer.Create('bgCitizens_StateArrestAction', 0.5, 0, function()
    for _, actor in ipairs(bgCitizens:GetAllByType('police')) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            if state == 'arrest'  then
                if not IsValid(data.attacker) then
                    actor:Idle()
                else
                    data.delay = data.delay or 0

                    local delayIgnore = arrest_players[data.attacker].delayIgnore

                    if delayIgnore < CurTime() then
                        actor:AddTarget(data.attacker)
                        actor:Defense()
                        return
                    end

                    if npc:GetTarget() ~= data.attacker then
                        npc:SetTarget(data.attacker)
                    end

                    if data.delay < CurTime() then
                        bgCitizens:SetActorWeapon(actor)

                        local point = nil
                        local current_distance = npc:GetPos():DistToSqr(data.attacker:GetPos())

                        if current_distance > 1000 ^ 2 then
                            point = actor:GetClosestPointToPosition(data.attacker:GetPos())
                        else
                            point = data.attacker:GetPos()
                        end

                        if point ~= nil then
                            npc:SetSaveValue("m_vecLastPosition", point)
                            npc:SetSchedule(SCHED_FORCED_GO_RUN)
                        end

                        local eyeAngles = data.attacker:EyeAngles()
                        data.arrest_time = data.arrest_time or 0
                        data.arrested = data.arrested or false

                        if eyeAngles.x > 40 then
                            if not data.arrested then
                                npc:EmitSound('npc/metropolice/vo/apply.wav', 
                                    300, 100, 1, CHAN_AUTO)
                                data.attacker:ChatPrint('Так и стой')
                                data.arrest_time = CurTime() + 5
                            end
                            data.arrested = true
                        elseif data.arrested then
                            data.arrested = false
                            data.arrest_time = CurTime() + 5
                        end

                        if not data.arrested and arrest_players[data.attacker].notify_delay < CurTime() then
                            data.attacker:ChatPrint('Опусти голову!')

                            npc:EmitSound('npc/metropolice/vo/firstwarningmove.wav', 
                                300, 100, 1, CHAN_AUTO)
                                
                            arrest_players[data.attacker].notify_delay = CurTime() + 3
                        elseif data.arrested then
                            delayIgnore = delayIgnore + 1
                            arrest_players[data.attacker].delayIgnore = delayIgnore

                            local time = data.arrest_time - CurTime()
                            if time <= 0 then
                                arrest_players[data.attacker] = nil

                                hook.Run('bgCitizens_PlayerArrest', data.attacker, actor)
                                for _, actor in ipairs(bgCitizens:GetAll()) do
                                    actor:RemoveTarget(data.attacker)
                                end
                                return
                            else
                                if arrest_players[data.attacker].notify_delay < CurTime() then
                                    data.attacker:ChatPrint('Арест через ' .. math.floor(time) .. ' секунд')
                                    arrest_players[data.attacker].notify_delay = CurTime() + 1
                                end
                            end
                        end

                        data.delay = CurTime() + 1
                    end
                end
            end
        end
    end
end)

hook.Add("bgCitizens_PlayerArrest", "DarkRPArestedNPC", function(ply, actor)
    if ply.arrest ~= nil then
        ply:arrest(nil, actor:GetNPC())
    end
end)