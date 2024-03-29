local cvar_ba2 = GetConVar('bgn_module_bio_annihilation_two_replacement')

hook.Add('BGN_OverrideSpawnData', 'BGM_ReplaceZombieClassToBioAnnihilationTwo', function(npcType, npcData)
	if npcType ~= 'zombie' then return end
	if not BA2_CustomInfs then return end
	if not cvar_ba2:GetBool() then return end
	return npcData, table.RandomBySeq({
		'nb_ba2_infected_custom',
		'nb_ba2_infected_citizen',
		'nb_ba2_infected_rebel',
	})
end)