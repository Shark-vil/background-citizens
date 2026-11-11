hook.Add('playerArrested', 'BGN_DarkRP_GamemodePlayerArrest', function(ply)
  local asset = bgNPC.Modules.Get('wanted')
  if asset:HasWanted(ply) then asset:RemoveWanted(ply) end
end)
