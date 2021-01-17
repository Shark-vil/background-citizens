hook.Add("PlayerDeath", "BGN_ClearingTargetsForNPCsInThePlayerDeath", function(victim, inflictor, attacker)
    bgNPC.killing_statistic[victim] = {}
    bgNPC.arrest_players[victim] = nil
    
    for _, actor in ipairs(bgNPC:GetAll()) do
        actor:RemoveTarget(victim)
    end
end)

hook.Add("BGN_ResetTargetsForActor", "BGN_SetDefaultStateIfTargetDeath", function(actor)
    local npc = actor:GetNPC()
    if IsValid(npc) then
        local wep = npc:GetActiveWeapon()
        if IsValid(wep) then
            wep:Remove()
        end

        if math.random(0, 10) > 5 then
            actor:Walk()
        else
            actor:Idle()
        end
    end
end)

timer.Create('BGN_Timer_ResetFearAndDefenseStateIfNoEnemies', 0.5, 0, function()
    for _, actor in ipairs(bgNPC:GetAll()) do
        actor:RecalculationTargets()
    end
end)