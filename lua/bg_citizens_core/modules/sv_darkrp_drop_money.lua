hook.Add("bgCitizens_OnKilledActor", "bgCitizensDropMoney", function(actor)
    if engine.ActiveGamemode() ~= 'darkrp' then return end

    local data = actor:GetData()
    local npc = actor:GetNPC()

    if IsValid(npc) then
        local pos = npc:GetPos()
        if data.money ~= nil then
            local money = math.random(data.money[1], data.money[2])
            DarkRP.createMoneyBag(pos, money)
        end
    end
end)