hook.Add('NBC_PlayerDisconnectedBypass', 'BGN_CancelNPCRemover', function(npc)
   return bgNPC:GetActor(npc) ~= nil
end)