local debug_cvar = GetConVar('bgn_debug')
hook.Add('BGN_InitActor', 'BGN_Debug_Spawn', function(actor)
  actor.debug_spawn = {
    pos = actor:GetPos(),
    time = CurTime()
  }
end)

hook.Add('BGN_RespawnActor', 'BGN_Debug_Teleport', function(actor, pos)
  actor.debug_teleport = {
    pos = pos,
    time = CurTime()
  }
end)

-- Position snapshots also cover actors outside the client's PVS, without forcing entity transmission.
timer.Create('BGN_Debug_ActorOverlay', 0.5, 0, function()
  if not debug_cvar:GetBool() then return end
  local recipients = {}
  for _, ply in ipairs(player.GetHumans()) do
    if ply.bgn_ready and (ply:IsAdmin() or ply:IsSuperAdmin()) then recipients[#recipients + 1] = ply end
  end

  if #recipients == 0 then return end
  local rows, counts, types = {}, {}, {}
  local now = CurTime()
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    if actor:IsAlive() and IsValid(actor:GetNPC()) then
      local npc = actor:GetNPC()
      local actor_type = actor:GetType()
      counts[actor_type] = (counts[actor_type] or 0) + 1
      rows[#rows + 1] = {
        uid = actor.uid,
        type = actor_type,
        pos = npc:GetPos(),
        ang = npc:GetAngles(),
        mins = npc:OBBMins(),
        maxs = npc:OBBMaxs(),
        hp = actor:Health(),
        state = actor:GetState(),
        in_vehicle = actor:InVehicle(),
        body = actor:InVehicle() and 'vehicle' or (npc:IsNextBot() and 'nextbot' or 'npc'),
        brain = bgNPC.Brain.Resolve(actor),
        lod = actor.lod,
        enemies = actor.enemies_count,
        targets = actor.targets_count,
        spawn_age = actor.debug_spawn and now - actor.debug_spawn.time,
        spawn_pos = actor.debug_spawn and now - actor.debug_spawn.time < 5 and actor.debug_spawn.pos or nil,
        teleport_age = actor.debug_teleport and now - actor.debug_teleport.time,
        teleport_pos = actor.debug_teleport and now - actor.debug_teleport.time < 5 and actor.debug_teleport.pos or nil,
      }
    end
  end

  for actor_type in SortedPairs(bgNPC.cfg.actors) do
    if bgNPC.Config.IsTypeActive(actor_type) or counts[actor_type] then
      types[#types + 1] = {
        name = actor_type,
        count = counts[actor_type] or 0,
        limit = bgNPC.Config.GetTypeLimit(actor_type)
      }
    end
  end

  bgNPC.Net.Send('bgn.debug_actors', recipients, rows, {
    types = types,
    nav = bgNPC.Nav.GetName(),
    points = bgNPC.Points.Count(),
    tasks_ms = bgNPC.Tasks.last_tick_ms or 0,
    lagging = bgNPC.ServerLoad.IsLagging(),
  })
end)
