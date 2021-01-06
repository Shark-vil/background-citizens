hook.Add("bgCitizen_SetNPCState", "NPCSetIdleAnimation", function(actor, state, data)
    if state == 'idle' then
        local id = tostring(math.random(1, 4))
        if actor:PlayStaticSequence('LineIdle0' .. id, true, 10) then
            return
        end
    end
end)

timer.Create('bgCitizens_ChangeIdleStateToWalk', 1, 0, function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local state = actor:GetState()
        local data = actor:GetStateData()
        if state == 'idle' and data.delay < CurTime() then
            actor:Walk()
        end
    end
end)