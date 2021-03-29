local n2MoneyExist = nil
hook.Add("BGN_DropMoney", "BGN_n2MoneyNPCDropMoney", function(actor, pos, money)
	if n2MoneyExist == nil then
		n2MoneyExist = scripted_ents.GetList()['ent_money'] ~= nil
	elseif n2MoneyExist == false then
		return
	end

	local dropped_ent = ents.Create("ent_money")
   dropped_ent:SetPos(pos)
   dropped_ent:Spawn()
   dropped_ent:SetNWString("DroppedMoneyAmount", tostring(money))
end)