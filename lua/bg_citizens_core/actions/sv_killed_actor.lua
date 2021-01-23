hook.Add("OnNPCKilled", "BGN_OnKilledActor", function(npc, attacker, inflictor)
    local actor = bgNPC:GetActor(npc)
    if actor ~= nil then
        bgNPC:AddKillingStatistic(attacker, actor)
        hook.Run('BGN_OnKilledActor', actor, attacker)
    end
end)