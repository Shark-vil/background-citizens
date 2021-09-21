hook.Add('playerArrested', 'BGN_DarkRP_GamemodePlayerArrest', function(ply)
	local asset = bgNPC:GetModule('wanted')

	if asset:HasWanted(ply) then
		asset:RemoveWanted(ply)
	end
end)