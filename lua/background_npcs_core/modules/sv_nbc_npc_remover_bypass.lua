hook.Add('NBC_PlayerDisconnectedBypass', 'BGN_CancelNPCRemover', function(npc) return bgNPC.Actors.Get(npc) ~= nil end)
