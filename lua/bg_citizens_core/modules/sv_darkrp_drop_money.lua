hook.Add('BGN_OnKilledActor', 'BGN_DarkRP_DefaultNPCDropMoney', function(actor)
	if engine.ActiveGamemode() ~= 'darkrp' then return end

	local data = actor:GetData()
	local npc = actor:GetNPC()

	if not IsValid(npc) then return end

	local pos = npc:GetPos()
	if data.money then return end

	local money = math.random(data.money[1], data.money[2])
	DarkRP.createMoneyBag(pos, money)
end)