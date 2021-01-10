hook.Add('BGN_PreSpawnNPC', 'BGN_SetCustomCitizenTypeFromDefaultModels', function(npc, data)
	if data.type == 'gangster' then
		npc:SetKeyValue('citizentype', 3)
	elseif data.type == 'citizen' and math.random(0, 10) > 5 then
		npc:SetKeyValue('citizentype', 2)
	end
end)