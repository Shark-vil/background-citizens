--[[
    We add the player to the arrest module, and increase the level of violation
    if he continues to inflict damage.
--]]
hook.Add("BGN_PreReactionTakeDamage", "BGN_AttackerRegistrationOnArrestTable", 
function(attacker, target, dmginfo, reaction)
    if reaction == 'defense' then return end
    if not GetConVar('bgn_arrest_mode'):GetBool() then return end
    if #bgNPC:GetAllByType('police') == 0 then return end

    local asset = bgNPC:GetModule('player_arrest')
    if asset == nil then return end
    
    local ActorTarget = bgNPC:GetActor(target)
    if attacker:IsPlayer() and ActorTarget ~= nil and ActorTarget:GetType() == 'citizen' then
        if not asset:HasPlayer(attacker) then
            asset:AddPlayer(attacker)
        else
            local c_Arrest = asset:GetPlayer(attacker)
            c_Arrest.count = c_Arrest.count + 1

            if c_Arrest.count >= 3 then
                c_Arrest.delayIgnore = 0
            end
        end
    end
end)

--[[
    Reset the timer ignore violations if the player killed the actor during the arrest.
--]]
hook.Add("BGN_OnKilledActor", "BGN_ResettingNPCFromTheArrestTableAfterDeath", function(actor, attacker)
    local asset = bgNPC:GetModule('player_arrest')
    if asset == nil then return end

    if asset:HasPlayer(attacker) then
        local c_Arrest = asset:GetPlayer(attacker)
        c_Arrest.delayIgnore = 0
    end
end)

--[[
    An overload of the standard reaction of the actor state.
--]]
local function ReactionOverride(actor, reaction)
    actor:SetReaction(reaction == 'arrest' and 'defense' or reaction)
end

--[[
    Actions performed by other actors if an ally takes damage.
--]]
hook.Add("BGN_PreDamageToAnotherActor", "BGN_EnableArrestStateForPolice", 
function(actor, attacker, target, reaction)
    local asset = bgNPC:GetModule('player_arrest')
    if asset == nil then return end

    local c_Arrest = asset:GetPlayer(attacker)

    if not IsValid(attacker) or not GetConVar('bgn_arrest_mode'):GetBool() 
        or c_Arrest == nil or c_Arrest.not_arrest
    then
        ReactionOverride(actor, reaction)
        return
    end

    local police = bgNPC:GetNearByType(attacker:GetPos(), 'police')
    if not IsValid(police) then
        ReactionOverride(actor, reaction)
        c_Arrest.not_arrest = true
        return
    end

    if not actor:HasTeam('police') then
        return false
    end

    police:AddTarget(attacker)
    police:SetState('arrest')

    return false
end)

--[[
    Arrest state processing timer.
--]]
timer.Create('BGN_Timer_CheckingTheStateOfArrest', 1, 0, function()
    local addArrestTime = GetConVar('bgn_arrest_time'):GetFloat()

    for _, actor in ipairs(bgNPC:GetAllByType('police')) do
        if actor:IsAlive() then
            local state = actor:GetState()
            
            if state == 'arrest' then
                if actor:TargetsCount() == 0 then
                    actor:Idle()
                else
                    local npc = actor:GetNPC()
                    local target = actor:GetNearTarget()
                    local data = actor:GetStateData()
                    data.delay = data.delay or 0

                    local asset = bgNPC:GetModule('player_arrest')
                    if asset == nil then
                        MsgN('[Background NPCs] Notification: "player_arrest" module not found, timer for state stopped.')
                        timer.Remove('BGN_Timer_CheckingTheStateOfArrest')
                        return
                    end

                    if not asset:HasPlayer(target) then
                        goto skip
                    end

                    local c_Arrest = asset:GetPlayer(target)

                    if c_Arrest.delayIgnore < CurTime() then
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
                                npc:EmitSound('npc/metropolice/vo/apply.wav', 300, 100, 1, CHAN_AUTO)
                                target:ChatPrint('Stay in this position, don\'t move!')
                                data.arrest_time = CurTime() + addArrestTime
                            end
                            data.arrested = true
                        elseif data.arrested then
                            data.arrested = false
                            data.arrest_time = CurTime() + addArrestTime
                        end

                        if not data.arrested and c_Arrest.notify_delay < CurTime() then
                            c_Arrest.notify_delay = CurTime() + 3
                            target:ChatPrint('Put your head down!')
                            npc:EmitSound('npc/metropolice/vo/firstwarningmove.wav', 300, 100, 1, CHAN_AUTO)
                        elseif data.arrested then
                            c_Arrest.delayIgnore = c_Arrest.delayIgnore + 1

                            local time = data.arrest_time - CurTime()
                            if time <= 0 then
                                c_Arrest:RemovePlayer(target)

                                hook.Run('BGN_PlayerArrest', target, actor)
                                for _, actor in ipairs(bgNPC:GetAll()) do
                                    actor:RemoveTarget(target)
                                end
                                return
                            else
                                c_Arrest.notify_arrest = c_Arrest.notify_arrest or 0

                                if c_Arrest.notify_arrest < CurTime() then
                                    target:ChatPrint('Arrest after ' .. math.floor(time) .. ' sec.')
                                    c_Arrest.notify_arrest = CurTime() + 1
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

--[[
    -- DarkRP --
    Arrests the player and teleports them to the prison cell if any.
--]]
hook.Add("BGN_PlayerArrest", "BGN_DarkRP_DefaultPlayerArrest", function(ply, actor)
    if ply.arrest ~= nil then
        ply:arrest(nil, actor:GetNPC())
    end
end)