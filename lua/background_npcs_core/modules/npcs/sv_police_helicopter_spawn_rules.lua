hook.Add('BGN_PreSpawnActor', 'BGN_SetPoliceHelicopterUpperPosition', function(npc, type, data)
	if type ~= 'police_helicopter' then return end

	local pos = npc:GetPos()
	npc:SetPos(pos + Vector(0, 0, 500))

	if data.class == 'npc_apache_scp_sb' then
		npc.ConstOnly = true
		npc.RocketLock = true
		npc.StartHealth = 300
	end
end)

timer.Create('BGN_PoliceHelicopterSetTarget', 1, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByType('police_helicopter')) do
		if actor:IsAlive() and actor.class == 'npc_apache_scp_sb' then
			local enemy = actor:GetNearEnemy()
			if IsValid(enemy) then
				actor:GetNPC().ConstTarget = enemy
			end
		end
	end
end)