hook.Add('BGN_PreSpawnNPC', 'BGN_SetCustomGangsterTypeFromDefaultModels', function(npc, type, data)
	if type ~= 'gangster' then return end
	npc:SetKeyValue('citizentype', 3)
end)