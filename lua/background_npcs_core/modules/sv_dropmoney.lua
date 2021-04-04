hook.Add("BGN_OnKilledActor", "BGN_Module_DropMoney", function(actor)
	local data = actor:GetData()
	local npc = actor:GetNPC()

	if IsValid(npc) then
		local pos = npc:GetPos() + npc:GetUp() * 10 + npc:GetForward() * 20
		if data.money == nil then return end

      local money = 0

      if isnumber(data.money) then
         money = data.money
      elseif istable(data.money) then
         money = math.random(data.money[1], data.money[2])
      end

      if money == 0 then return end

      hook.Run('BGN_DropMoney', actor, pos, money)
	end
end)