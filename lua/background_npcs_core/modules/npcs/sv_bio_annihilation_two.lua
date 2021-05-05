hook.Add('BGN_OverrideSpawnData', 'BGM_ReplaceZombieClassToBioAnnihilationTwo', function(npcType, npcData)
	if npcType ~= 'zombie' then return end
	if not BA2_CustomInfs then return end
	if not npcData.bio_annihilation_two_replacement then return end
	return npcData, array.Random({
		'nb_ba2_infected_custom',
		'nb_ba2_infected_citizen',
		'nb_ba2_infected_rebel',
	})
end)