timer.Create('bgn_timer_npc_look_at_object', 0.5, 0, function()
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