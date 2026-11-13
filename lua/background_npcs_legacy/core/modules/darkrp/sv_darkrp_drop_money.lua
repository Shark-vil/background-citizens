hook.Add('BGN_DropMoney', 'BGN_DarkRP_DropMoney', function(actor, pos, money)
	if engine.ActiveGamemode() ~= 'darkrp' then return end
	DarkRP.createMoneyBag(pos, money)
end)