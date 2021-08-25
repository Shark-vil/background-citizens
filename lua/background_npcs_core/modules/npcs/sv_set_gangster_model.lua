hook.Add('BGN_PreSpawnActor', 'BGN_SetCustomGangsterTypeFromDefaultModels', function(npc, npc_type, data)
	if npc_type ~= 'gangster' then return end
	npc:SetKeyValue('citizentype', 3)
end)