timer.Create('bgCitizensCreator', GetConVar('bg_citizens_spawn_period'):GetFloat(), 0, function()
    local bg_citizens_enable = GetConVar('bg_citizens_enable'):GetInt()

    if bg_citizens_enable <= 0 then
        return
    end

    local bg_citizens_max_npc = GetConVar('bg_citizens_max_npc'):GetInt()
    
    bgCitizens:ClearRemovedNPCs()

    if #bgCitizens:GetAll() < bg_citizens_max_npc then
        for _, npc_data in ipairs(bgCitizens.npc_classes) do
            local count = table.Count(bgCitizens:GetAllNPCsByType(npc_data.type))
            local max = math.Round(((npc_data.fullness / 100) * bg_citizens_max_npc))

            if max <= 0 or count > max then
                goto skip
            end

            bgCitizens:SpawnActor(npc_data.type)

            ::skip::
        end
    end
end)

hook.Add("Think", "bgCitizensLoopAnimatorController", function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            if actor:IsAnimationPlayed() then
                npc:SetNPCState(NPC_STATE_SCRIPT)
                npc:SetSchedule(SCHED_SLEEP)

                if actor:IsLoopSequence() then
                    if actor:IsSequenceLoopFinished() then
                        actor:ResetSequence()
                    elseif actor:IsSequenceFinished() then
                        npc:ResetSequenceInfo()
                        npc:SetSequence(npc:LookupSequence(actor.anim_name))
                    end
                elseif actor:IsSequenceFinished() then
                    actor:ResetSequence()
                end
            end
        end
    end
end)

hook.Add("Think", "bgCitizensPlayerLookObjectTime", function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() then
            local tr = util.TraceLine({
                start = ply:EyePos(),
                endpos = ply:EyePos() + ply:EyeAngles():Forward() * 1000,
                filter = function(ent) 
                    if ent ~= ply then return true end
                end
            })

            local ent = tr.Entity

            if tr.Hit and IsValid(ent) then
                ply.bgCitizensLookObject = ply.bgCitizensLookObject or ent
                ply.bgCitizensLookObjectTime = ply.bgCitizensLookObjectTime or RealTime()

                if ply.bgCitizensLookObject ~= ent then
                    ply.bgCitizensLookObject = ent
                    ply.bgCitizensLookObjectTime = RealTime()
                end

                local LookTime = RealTime() - ply.bgCitizensLookObjectTime

                local result = hook.Run('bgCitizens_PlayerLookAtObject', ply, ent, LookTime)
                if result ~= nil and isbool(result) and result then
                    ply.bgCitizensLookObjectTime = RealTime()
                end
            end
        end
    end
end)

timer.Create('bgCitizensTimerNPCLookAtObjectAction', 1, 0, function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local npc = actor:GetNPC()
        
            local tr = util.TraceLine({
                start = npc:GetShootPos(),
                endpos = npc:GetShootPos() + npc:EyeAngles():Forward() * 1000,
                filter = function(ent) 
                    if ent ~= npc then return true end
                end
            })

            if tr.Hit and IsValid(tr.Entity) then
                hook.Run('bgCitizens_NPCLookAtObject', actor, tr.Entity)
            end
        end
    end
end)

--[[
hook.Add("bgCitizens_PlayerLookAtObject", "PoliceAgressionIfPlayerLongLook", function(ply, ent, time)
    local actor = bgCitizens:GetActor(ent)
    if actor == nil then return end

    local npc = actor:GetNPC()
    if actor:GetType() == 'police' and actor:GetState() == 'walk' 
        and bgCitizens:NPCIsViewVector(npc, ply:GetPos(), 60)
        and actor:IsSequenceFinished()
    then
        if ply:GetPos():DistToSqr(npc:GetPos()) > 200 ^ 2 then return true end

        if time > 7 then
            local plyAngle = ply:GetAngles()
            local npcAngle = npc:GetAngles()
            local newAngle = npcAngle
            newAngle.y = plyAngle.y - 180
            npc:SetAngles(newAngle)

            if not actor:HasSequence('MotionLeft') or actor:IsSequenceFinished() then
                actor:PlayStaticSequence('MotionLeft')
                return true
            end
        end
    end
end)
]]

hook.Add("bgCitizens_NPCLookAtObject", "PolicePushAnotherNPC", function(actor, ent)
    if ent:IsPlayer() and actor:GetType() == 'police' 
        and actor:GetState() == 'walk'
        and actor:IsSequenceFinished()
    then
        if ent:GetPos():DistToSqr(actor:GetNPC():GetPos()) > 50 ^ 2 then return end

        local data = actor:GetStateData()
        data.LuggageWarn = data.LuggageWarn or 0

        if data.LuggageWarn < 2 then
            actor:PlayStaticSequence('LuggageWarn')
            data.LuggageWarn = data.LuggageWarn + 1
        else
            actor:PlayStaticSequence('LuggagePush')

            local forward = actor:GetNPC():GetForward()

            local angle_punch_pitch = math.Rand(-20, 20)
            local angle_punch_yaw = math.sqrt(20 * 20 - angle_punch_pitch * angle_punch_pitch)
            if math.random(0, 1) == 1 then
                angle_punch_yaw = angle_punch_yaw * -1
            end
            ent:ViewPunch(Angle(angle_punch_pitch, angle_punch_yaw, 0))

            local slapSounds = {
                "physics/body/body_medium_impact_hard1.wav",
                "physics/body/body_medium_impact_hard2.wav",
                "physics/body/body_medium_impact_hard3.wav",
                "physics/body/body_medium_impact_hard5.wav",
                "physics/body/body_medium_impact_hard6.wav",
                "physics/body/body_medium_impact_soft5.wav",
                "physics/body/body_medium_impact_soft6.wav",
                "physics/body/body_medium_impact_soft7.wav",
            }

            ent:EmitSound(table.Random(slapSounds), 75, 100, 0.3, CHAN_AUTO)
            ent:SetVelocity(forward * 250)

            data.LuggageWarn = 0
        end
    end
end)