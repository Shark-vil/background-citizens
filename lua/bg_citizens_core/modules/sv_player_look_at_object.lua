timer.Create('bgn_timer_player_look_at_object', 0.3, 0, function()
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