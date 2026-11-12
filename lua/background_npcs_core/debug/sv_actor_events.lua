local I = bgNPC.DebugInspector
I.sessions = {}

function I.Observed(ent)
  if not next(I.sessions) or not GetConVar('bgn_debug'):GetBool() then return false end
  local a = istable(ent) and ent.isBgnClass and ent or bgNPC.Actors.Get(ent)
  local s = a and I.sessions[a.uid]
  return s and s.expires > CurTime() and s or false
end

function I.Name(ent)
  if not IsValid(ent) then return '-' end
  local a = bgNPC.Actors.Get(ent)
  return a and a:GetType() .. ' #' .. a.uid or (ent:IsPlayer() and ent:Nick() or ent:GetClass()) .. ' [' .. ent:EntIndex() .. ']'
end

local function Push(s, event)
  if s.count==256 then s.dropped=s.dropped+1 end
  s.head = s.head % 256 + 1
  s.events[s.head] = event
  s.count = math.min(256, s.count + 1)
  s.serial = s.serial + 1
end

function I.Subscribe(actor, expires, vision, signals)
  local s = I.sessions[actor.uid]
  if not s or s.expires < CurTime() then
    s = {events = {}, sights = {}, head = 0, count = 0, serial = 0, dropped = 0}
    I.sessions[actor.uid] = s
  end
  s.expires = math.max(s.expires or 0, expires)
  s.vision, s.signals = vision, signals
  return s
end

function I.Emit(actor, kind, target, reason, source, accepted)
  local own, from, to = I.Observed(actor), source and I.Observed(source), target and I.Observed(target)
  if source then
    own = own and own.signals and own
    from = from and from.signals and from
    to = to and to.signals and to
  end
  if not own and not from and not to then return end
  local npc = actor:GetNPC()
  if not IsValid(npc) then return end
  local event = {time = CurTime(), kind = kind, actor = I.Name(npc), target = I.Name(target),
    source = I.Name(source), reason = reason or '', accepted = accepted,
    pos = npc:GetPos(), from = IsValid(source) and source:WorldSpaceCenter() or npc:WorldSpaceCenter(),
    to = IsValid(source) and npc:WorldSpaceCenter() or (IsValid(target) and target:WorldSpaceCenter() or npc:WorldSpaceCenter())}
  if own then Push(own, event) end
  if from and from ~= own then Push(from, event) end
  if to and to ~= own and to ~= from then Push(to, event) end
end

function I.Sight(watcher, target, visible, channel, tr, in_view)
  local s = I.Observed(watcher)
  if not s or not s.vision then return end
  local key = target:EntIndex() .. ':' .. channel
  local old = s.sights[key]
  if old and old.time + 0.2 > CurTime() and old.visible == visible then return end
  if not old and table.Count(s.sights) >= 64 then s.dropped = s.dropped + 1 return end
  local viewer = watcher.GetViewEntity and watcher:GetViewEntity() or watcher
  s.sights[key] = {time = CurTime(), target = I.Name(target), visible = visible, channel = channel,
    from = tr and tr.StartPos or viewer:EyePos(), to = target:WorldSpaceCenter(),
    direction = in_view~=nil and IsValid(viewer) and viewer.GetAimVector and viewer:GetAimVector() or nil,
    hit = tr and tr.HitPos, blocker = tr and not visible and (tr.HitWorld and 'world' or I.Name(tr.Entity)) or '-', in_view = in_view}
end

function I.Export(actor, seconds)
  local s = I.Observed(actor)
  local events, sights = {}, {}
  if not s then return events, sights, 0 end
  local now = CurTime()
  for n = s.count - 1, 0, -1 do
    local e = s.events[(s.head - n - 1) % 256 + 1]
    if now - e.time <= seconds then events[#events + 1] = e end
  end
  for key, sight in pairs(s.sights) do
    if now - sight.time <= seconds then sights[#sights + 1] = sight else s.sights[key] = nil end
  end
  table.sort(sights, function(a,b) return a.time>b.time end)
  return events, sights, s.dropped
end

hook.Add('BGN_SetState', 'BGN_Debug_Events', function(a, state)
  if a:GetOldState()~=state and I.Observed(a) then I.Emit(a, 'state', nil, a:GetOldState() .. ' -> ' .. state) end
end)
hook.Add('EntityTakeDamage', 'BGN_Debug_Events', function(npc, dmg)
  local a = bgNPC.Actors.Get(npc)
  if a and I.Observed(a) then I.Emit(a, 'damage_attempt', dmg:GetAttacker(), tostring(dmg:GetDamage())) end
end)
hook.Add('BGN_PostReactionTakeDamage', 'BGN_Debug_Events', function(attacker, victim)
  local a = bgNPC.Actors.Get(victim)
  if a and I.Observed(a) then I.Emit(a, 'damage', attacker, a:GetLastReaction()) end
end)
hook.Add('BGN_PostDamageToAnotherActor', 'BGN_Debug_Events', function(a, attacker)
  if I.Observed(a) then I.Emit(a, 'witness', attacker, a:GetLastReaction()) end
end)
hook.Add('PostCleanupMap', 'BGN_Debug_Events', function() I.sessions = {} end)
timer.Create('BGN_Debug_EventsCleanup', 3, 0, function()
  for uid, s in pairs(I.sessions) do if s.expires < CurTime() then I.sessions[uid] = nil end end
end)
