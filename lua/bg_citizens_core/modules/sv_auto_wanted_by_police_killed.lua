hook.Add("BGN_OnKilledActor", "BGN_AutomaticWantedModeAfterKillingManyPolice", function(actor, attacker)
    if not GetConVar('bgn_enable_wanted_mode'):GetBool() then return end

    -- if attacker:IsPlayer() then
    --     local count = bgNPC:AddKillingStatistic(attacker, actor)
    --     if not bgNPC:IsWanted(attacker) and actor:GetType() == 'police' and count > 3 then
    --         bgNPC:AddWanted(attacker)
    --     end
    -- end
end)