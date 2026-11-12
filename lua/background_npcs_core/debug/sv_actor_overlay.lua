local function Row(a)
  local npc = a:GetNPC()
  return {
    uid = a.uid,
    type = a:GetType(),
    state = a:GetState(),
    pos = npc:GetPos(),
    ang = npc:GetAngles(),
    mins = npc:OBBMins(),
    maxs = npc:OBBMaxs(),
    hp = a:Health(),
    enemies = a.enemies_count,
    targets = a.targets_count,
    body = a:InVehicle() and 'vehicle' or (npc:IsNextBot() and 'nextbot' or 'npc'),
    brain = bgNPC.Brain.Resolve(a),
    lod = a.lod,
    team = table.concat(a.data.team or {}, ', ')
  }
end

local function Send(ply, overview)
  if not IsValid(ply) or not ply.bgn_ready or not (ply:IsAdmin() or ply:IsSuperAdmin()) or not GetConVar('bgn_debug'):GetBool() then return end
  local rows, count = {}, 0
  for _, a in ipairs(bgNPC.Actors.GetAll()) do
    if a:IsAlive() and IsValid(a:GetNPC()) and (not overview or a:GetPos():DistToSqr(ply:GetPos()) <= 25000000) then
      count = count + 1
      if #rows < 128 then rows[#rows + 1] = Row(a) end
    end
  end

  bgNPC.Net.Send('bgn.debug_roster', ply, rows, math.max(0, count - #rows))
end

bgNPC.Net.Receive('bgn.debug_roster', function(ply)
  if (ply.bgn_debug_roster_at or 0) > CurTime() then return end
  ply.bgn_debug_roster_at = CurTime() + 1
  Send(ply, false)
end, {
  admin = true
})

timer.Create('BGN_Debug_ActorOverlay', 0.5, 0, function()
  for ply, selection in pairs(bgNPC.DebugInspector.selections) do
    if selection.overview and bgNPC.DebugInspector.Selected(ply) then Send(ply, true) end
  end
end)
