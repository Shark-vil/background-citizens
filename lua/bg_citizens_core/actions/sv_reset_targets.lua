hook.Add("PlayerDeath", "BGN_ClearingTargetsForNPCsInThePlayerDeath", function(victim, inflictor, attacker)
    bgCitizens.killing_statistic[victim] = {}
    bgCitizens.arrest_players[victim] = nil
    
    for _, actor in ipairs(bgCitizens:GetAll()) do
        actor:RemoveTarget(victim)
    end
end)

timer.Create('BGN_Timer_ResetFearAndDefenseStateIfNoEnemies', 0.5, 0, function()
    for _, actor in ipairs(bgCitizens:GetAll()) do
        local npc = actor:GetNPC()
        if IsValid(npc) then
            local state = actor:GetState()

            if state == 'defense' or state == 'fear' then
                actor:RecalculationTargets()
                
                if actor:TargetsCount() == 0 then        
                    local wep = npc:GetActiveWeapon()
                    if IsValid(wep) then
                        wep:Remove()
                    end

                    if math.random(0, 10) > 5 then
                        actor:Walk()
                    else
                        actor:Idle()
                    end

                    goto skip
                end
            end
        end

        ::skip::
    end
end)