hook.Add('BGN_PreSpawnNPC', 'BGN_SetPoliceHelicopterUpperPosition', function(npc, type, data)
	if type ~= 'police_helicopter' then return end
	
	local pos = npc:GetPos()
	npc:SetPos(pos + Vector(0, 0, 600))
end)