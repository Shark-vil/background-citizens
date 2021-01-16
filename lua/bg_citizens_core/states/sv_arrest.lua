
bgNPC.arrest_players = {}

hook.Add("BGN_PreReactionTakeDamage", "BGN_AttackerRegistrationOnArrestTable", 
function(attacker, target, dmginfo, reaction)
    if reaction == 'defense' then return end
    if not GetConVar('bgn_arrest_mode'):GetBool() then return end
    if #bgNPC:GetAllByType('police') == 0 then return end
    
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
            delay = CurTime() + 1.5,
            delayIgnore = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
            arrestTime = GetConVar('bgn_arrest_time'):GetFloat(),
            notify_delay = 0,
            not_arrest = false,
            count = 1
        }
    end
end)

hook.Add("BGN_OnKilledActor", "BGN_ResettingNPCFromTheArrestTableAfterDeath", function(actor, attacker)
    if bgNPC.arrest_players[attacker] ~= nil then
        bgNPC.arrest_players[attacker].delayIgnore = 0
    end
end)

local function ReactionOverride(actor, reaction)
    actor:SetReaction(reaction == 'arrest' and 'defense' or reaction)
end

hook.Add("BGN_PreDamageToAnotherActor", "BGN_EnableArrestStateForPolice", 
function(actor, attacker, target, reaction)
    if not IsValid(attacker) or not GetConVar('bgn_arrest_mode'):GetBool() 
        or bgNPC.arrest_players[attacker] == nil or bgNPC.arrest_players[attacker].not_arrest
    then
        ReactionOverride(actor, reaction)
        return
    end

    local police = bgNPC:GetNearByType(attacker:GetPos(), 'police')
    if not IsValid(police) then
        ReactionOverride(actor, reaction)
        bgNPC.arrest_players[attacker].not_arrest = true
        return
    end

    if not actor:HasTeam('police') then
        return false
    end

    police:AddTarget(attacker)
    police:SetState('arrest')

    return false
end)

timer.Create('BGN_Timer_CheckingTheStateOfArrest', 1, 0, function()    
    for _, actor in ipairs(bgNPC:GetAllByType('police')) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()
            local data = actor:GetStateData()

            if state == 'arrest' then
                local target = actor:GetNearTarget()

                if actor:TargetsCount() == 0 then
                    actor:Idle()
                else                    
                    data.delay = data.delay or 0

                    if bgNPC.arrest_players[target] == nil then
                        goto skip
                    end

                    local delayIgnore = bgNPC.arrest_players[target].delayIgnore
                    local arrestTime = bgNPC.arrest_players[target].arrestTime

                    if delayIgnore < CurTime() then
                        actor:Defense()
                        goto skip
                    end

                    if npc:GetTarget() ~= target then
                        npc:SetTarget(target)
                    end

                    if data.delay < CurTime() then
                        bgNPC:SetActorWeapon(actor)

                        local point = nil
                        local current_distance = npc:GetPos():DistToSqr(target:GetPos())

                        if current_distance > 1000 ^ 2 then
                            point = actor:GetClosestPointToPosition(target:GetPos())
                        else
                            point = target:GetPos()
                        end
                        
                        if point ~= nil then
                            npc:SetSaveValue("m_vecLastPosition", point)
                            npc:SetSchedule(SCHED_FORCED_GO_RUN)
                        end

                        local eyeAngles = target:EyeAngles()
                        data.arrest_time = data.arrest_time or 0
                        data.arrested = data.arrested or false

                        if eyeAngles.x > 40 then
                            if not data.arrested then
                                npc:EmitSound('npc/metropolice/vo/apply.wav', 
                                    300, 100, 1, CHAN_AUTO)
                                    target:ChatPrint('Stay in this position, don\'t move!')
                                data.arrest_time = CurTime() + arrestTime
                            end
                            data.arrested = true
                        elseif data.arrested then
                            data.arrested = false
                            data.arrest_time = CurTime() + arrestTime
                        end

                        if not data.arrested 
                            and bgNPC.arrest_players[target].notify_delay < CurTime() 
                        then
                            bgNPC.arrest_players[target].notify_delay = CurTime() + 3
                            target:ChatPrint('Put your head down!')
                            npc:EmitSound('npc/metropolice/vo/firstwarningmove.wav', 
                                300, 100, 1, CHAN_AUTO)
                        elseif data.arrested then
                            delayIgnore = delayIgnore + 1
                            bgNPC.arrest_players[target].delayIgnore = delayIgnore

                            local time = data.arrest_time - CurTime()
                            if time <= 0 then
                                bgNPC.arrest_players[target] = nil

                                hook.Run('BGN_PlayerArrest', target, actor)
                                for _, actor in ipairs(bgNPC:GetAll()) do
                                    actor:RemoveTarget(target)
                                end
                                return
                            else
                                bgNPC.arrest_players[target].notify_arrest = 
                                    bgNPC.arrest_players[target].notify_arrest or 0

                                if bgNPC.arrest_players[target].notify_arrest < CurTime() then
                                    target:ChatPrint('Arrest after ' .. math.floor(time) .. ' sec.')
                                    bgNPC.arrest_players[target].notify_arrest = CurTime() + 1
                                end
                            end
                        end

                        data.delay = CurTime() + 1
                    end
                end
            end
        end

        ::skip::
    end
end)

hook.Add("BGN_PlayerArrest", "BGN_DarkRP_DefaultPlayerArrest", function(ply, actor)
    if ply.arrest ~= nil then
        ply:arrest(nil, actor:GetNPC())
    end
end)