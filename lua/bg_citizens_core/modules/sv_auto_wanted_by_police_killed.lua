hook.Add("BGN_OnKilledActor", "BGN_AutomaticWantedModeAfterKillingManyPolice", function(actor, attacker)
    if attacker:IsPlayer() then
        local count = bgNPC:AddKillingStatistic(attacker, actor)

        if bgNPC:GetEntityVariable(attacker, 'is_wanted', false) 
            and actor:GetType() == 'police' and count > 3
        then
            table.insert(bgNPC.wanted, attacker)
            bgNPC:SetEntityVariable(attacker, 'wanted_time_reset', CurTime() + bgNPC.wanted_time)
            bgNPC:SetEntityVariable(attacker, 'wanted_time', bgNPC.wanted_time)
            bgNPC:SetEntityVariable(attacker, 'is_wanted', true)
        end
    end
end)