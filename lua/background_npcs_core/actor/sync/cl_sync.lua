local LATEST_LIFETIME = 5
-- uid -> newest dynamic part. A static packet may wait for its entity (up to 3 s) and arrive after newer dynamic ones.
local latest = {}
bgNPC.Net.Receive('bgn_actor_sync_data', function(ply, uid, data, static, seq)
  seq = seq or 0
  local last = latest[uid]
  if last and last.seq > seq then data, seq = last.data, last.seq end
  latest[uid] = {
    seq = seq,
    data = data,
    expire = RealTime() + LATEST_LIFETIME
  }

  local actor
  if static then
    actor = bgNPC.Actors.ReceiveBinding(static.npc, static.actor_type, uid, nil, static.entity_generation, static.class, static.model)
    if not actor then return end
    actor:SetName(static.name)
    actor:SetGender(static.gender)
  else
    actor = bgNPC.Actors.GetByUid(uid)
    if not actor then return end
  end

  actor:SyncState(data.state)
  actor.state_group = data.state_group -- the client has no state registry (states are server files)
  actor.enemies = data.enemies
  actor.targets = data.targets
  actor.anim_name = data.anim_name
  actor.is_animated = data.is_animated
  actor.state_lock = data.state_lock
  actor.carry_visual = data.carry_visual or nil
  actor.reaction = data.reaction
end, {
  wait_entities = true
})

timer.Create('BGN_ActorSyncLatestCleanup', LATEST_LIFETIME, 0, function()
  local now = RealTime()
  for uid, entry in pairs(latest) do
    if entry.expire < now then latest[uid] = nil end
  end
end)
