hook.Add("BGN_OnKilledActor", "BGN_AutomaticWantedModeAfterKillingManyPolice", function(actor, attacker)
    if attacker:IsPlayer() then
        local count = bgCitizens:AddKillingStatistic(attacker, actor)

        if bgCitizens:GetEntityVariable(attacker, 'is_wanted', false) 
            and actor:GetType() == 'police' and count > 3
        then
            table.insert(bgCitizens.wanted, attacker)
            bgCitizens:SetEntityVariable(attacker, 'wanted_time_reset', CurTime() + bgCitizens.wanted_time)
            bgCitizens:SetEntityVariable(attacker, 'wanted_time', bgCitizens.wanted_time)
            bgCitizens:SetEntityVariable(attacker, 'is_wanted', true)
        end
    end
end)