hook.Add("bgCitizens_OnKilledActor", "bgCitizens_AutoLargeMurderWanted", function(actor, attacker)
    if attacker:IsPlayer() then
        local count = bgCitizens:AddKillingStatistic(attacker, actor)
        if not attacker:GetNWBool('bgCitizenWanted') and actor:GetType() == 'police' and count > 3 then
            table.insert(bgCitizens.wanted, attacker)
            attacker.bgCitizenWantedReset = CurTime() + 30
            attacker:SetNWBool('bgCitizenWanted', true)
        end
    end
end)