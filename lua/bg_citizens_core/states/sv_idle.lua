hook.Add("BGN_SetNPCState", "BGN_SetIdleNPCAnimationIfStateEqualIdle", function(actor, state, data)
    if state == 'idle' then
        local id = tostring(math.random(1, 4))
        if actor:PlayStaticSequence('LineIdle0' .. id, true, 10) then
            return
        end
    end
end)

timer.Create('BGN_ChangeIdleStateToWalk', 1, 0, function()
    for _, actor in ipairs(bgNPC:GetAll()) do
        local state = actor:GetState()
        local data = actor:GetStateData()
        if state == 'idle' and data.delay < CurTime() then
            actor:Walk()
        end
    end
end)