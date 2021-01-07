hook.Add("BGN_PreReactionTakeDamage", "BGN_AttackerRegistrationOnArrestTable", 
function(attacker, target, dmginfo)
    if not bgNPC.arrest_moode then return end
    
    local ActorTarget = bgNPC:GetActor(target)
    if attacker:IsPlayer() and ActorTarget ~= nil and ActorTarget:GetType() == 'citizen' then
        if bgNPC.arrest_players[attacker] ~= nil then 
            bgNPC.arrest_players[attacker].count = bgNPC.arrest_players[attacker].count + 1

            if bgNPC.arrest_players[attacker].delayIgnore > CurTime() 
                and bgNPC.arrest_players[attacker].count >= 3 
            then
                bgNPC.arrest_players[attacker].delayIgnore = 0
            end

            return 
        end
        
        bgNPC.arrest_players[attacker] = {
            target = target,
            delay = CurTime() + 1.5,
            delayIgnore = CurTime() + bgNPC.arrest_time_limit,
            count = 1
        }
    end
end)

hook.Add("BGN_OnKilledActor", "BGN_ResettingNPCFromTheArrestTableAfterDeath", function(actor, attacker)
    if bgNPC.arrest_players[attacker] ~= nil then
        bgNPC.arrest_players[attacker].delayIgnore = 0
    end
end)

hook.Add("BGN_DamageToAnotherActor", "BGN_EnableArrestStateForPolice", function(actor, attacker, target)
    if not IsValid(attacker) or not IsValid(target) then
        return
    end

    if bgNPC.arrest_players == nil or bgNPC.arrest_players[attacker] == nil 
        or bgNPC.arrest_players[attacker].target == nil 
        or not IsValid(bgNPC.arrest_players[attacker].target)
    then
        return
    end

    if bgNPC.arrest_players[attacker].arrest ~= nil 
        and not bgNPC.arrest_players[attacker].arrest 
    then
        return
    end

    if actor:GetType() == 'police' then
        if actor:GetReactionForProtect() ~= 'arrest' then
            bgNPC.arrest_players[attacker].arrest = false
            return
        end
    else
        if bgNPC.arrest_players[attacker].delay > CurTime() then
            return true
        end
    end

    bgNPC.arrest_players[attacker].arrest = true
    
    if bgNPC.arrest_players[attacker].target == target then
        bgNPC.arrest_players[attacker].notify_delay 
            = bgNPC.arrest_players[attacker].notify_delay or 0

        actor:SetState('arrest', {
            targets = target,
            attacker = attacker,
        })
        return true
    end
end)

timer.Create('BGN_Timer_CheckingTheStateOfArrest', 0.5, 0, function()    
    for _, actor in ipairs(bgNPC:GetAllByType('police')) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            if state == 'arrest'  then
                if not IsValid(data.attacker) then
                    actor:Idle()
                else
                    data.delay = data.delay or 0

                    local delayIgnore = bgNPC.arrest_players[data.attacker].delayIgnore

                    if delayIgnore < CurTime() then
                        actor:AddTarget(data.attacker)
                        actor:Defense()
                        return
                    end

                    if npc:GetTarget() ~= data.attacker then
                        npc:SetTarget(data.attacker)
                    end

                    if data.delay < CurTime() then
                        bgNPC:SetActorWeapon(actor)

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

                        if not data.arrested 
                            and bgNPC.arrest_players[data.attacker].notify_delay < CurTime() 
                        then
                            data.attacker:ChatPrint('Опусти голову!')

                            npc:EmitSound('npc/metropolice/vo/firstwarningmove.wav', 
                                300, 100, 1, CHAN_AUTO)
                                
                            bgNPC.arrest_players[data.attacker].notify_delay = CurTime() + 3
                        elseif data.arrested then
                            delayIgnore = delayIgnore + 1
                            bgNPC.arrest_players[data.attacker].delayIgnore = delayIgnore

                            local time = data.arrest_time - CurTime()
                            if time <= 0 then
                                bgNPC.arrest_players[data.attacker] = nil

                                hook.Run('BGN_PlayerArrest', data.attacker, actor)
                                for _, actor in ipairs(bgNPC:GetAll()) do
                                    actor:RemoveTarget(data.attacker)
                                end
                                return
                            else
                                if bgNPC.arrest_players[data.attacker].notify_delay < CurTime() then
                                    data.attacker:ChatPrint('Арест через ' .. math.floor(time) .. ' секунд')
                                    bgNPC.arrest_players[data.attacker].notify_delay = CurTime() + 1
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

hook.Add("BGN_PlayerArrest", "BGN_DarkRP_DefaultPlayerArrest", function(ply, actor)
    if ply.arrest ~= nil then
        ply:arrest(nil, actor:GetNPC())
    end
end)