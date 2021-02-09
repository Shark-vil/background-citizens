hook.Add('BGN_PreSpawnActor', 'BGN_SetCustomGangsterTypeFromDefaultModels', function(npc, type, data)
	if type ~= 'gangster' then return end
	npc:SetKeyValue('citizentype', 3)
end)