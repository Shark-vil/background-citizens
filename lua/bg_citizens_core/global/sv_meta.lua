function bgCitizens:IsFearNPC(npc)
    if IsValid(npc) and npc:IsNPC() then
        local schedule = npc:GetCurrentSchedule()
        if npc:IsCurrentSchedule(SCHED_RUN_FROM_ENEMY) 
            or npc:IsCurrentSchedule(SCHED_WAKE_ANGRY)
            or schedule == 159
        then
            return true
        end
    end
    return false
end