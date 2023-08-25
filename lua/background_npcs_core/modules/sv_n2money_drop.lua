local n2_money_exists = nil
local money_model = 'models/props/cs_assault/money.mdl'
local cvar_bgn_module_n2money = GetConVar('bgn_module_n2money')

hook.Add('BGN_DropMoney', 'BGN_n2MoneyNPCDropMoney', function(actor, pos, money)
	if not cvar_bgn_module_n2money:GetBool() then return end

	if not n2_money_exists then
		n2_money_exists = scripted_ents.GetList()['ent_money'] ~= nil

		if not util.IsValidModel(money_model) then
			n2_money_exists = false
			slib.Warning('"nMoney2" will not work without CSS content!')
		end

		if not n2_money_exists then
			hook.Remove('BGN_DropMoney', 'BGN_n2MoneyNPCDropMoney')
			return
		end
	end

	local dropped_ent = ents.Create('ent_money')
	dropped_ent:SetPos(pos)
	dropped_ent:Spawn()
	dropped_ent:SetNWString('DroppedMoneyAmount', tostring(money))
	dropped_ent:slibCreateTimer('auto_destroy', 30, 1, function(ent)
		if IsValid(ent) then ent:Remove() end
	end)
end)