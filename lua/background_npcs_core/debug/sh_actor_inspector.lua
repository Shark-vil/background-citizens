bgNPC.DebugInspector = bgNPC.DebugInspector or {}
local Inspector = bgNPC.DebugInspector
function Inspector.View(npc, snapshot)
  -- NextBot BGN_EyePos exists only on SERVER; interpolate its server eye frame with the client body.
  if snapshot then return npc:LocalToWorld(snapshot.eye_local), npc:LocalToWorldAngles(snapshot.aim_local) end
  local eye = npc.BGN_EyePos and npc:BGN_EyePos() or npc:EyePos()
  local direction = npc.GetAimVector and npc:GetAimVector() or npc:GetForward()
  return eye, direction:Angle()
end
