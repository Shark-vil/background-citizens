local I = bgNPC.DebugInspector
local selections, cache = {}, {}
I.selections = selections
local function Allowed(ply)
  return GetConVar('bgn_debug'):GetBool() and IsValid(ply) and ply.bgn_ready and (ply:IsAdmin() or ply:IsSuperAdmin())
end
local function Selected(ply)
  local s = selections[ply]
  if not s then return end
  local a = Allowed(ply) and s.expires > CurTime() and (not s.watch or ply:Alive()) and bgNPC.Actors.GetByUid(s.uid)
  if a and a:IsAlive() and IsValid(a:GetNPC()) then return a, s end
  selections[ply] = nil
end
I.Selected = Selected
local function Number(value, default, low, high)
  local n = tonumber(value)
  if not n or n~=n then return default end
  return math.Clamp(n,low,high)
end
bgNPC.Net.Receive('bgn.debug_select', function(ply, uid, watch, options)
  if not Allowed(ply) then return end
  if uid == nil then selections[ply] = nil return end
  if not isnumber(uid) or not isbool(watch) then return end
  local a = bgNPC.Actors.GetByUid(uid)
  if not a or not a:IsAlive() then return end
  options = istable(options) and options or {}
  local old = selections[ply]
  local s = {uid = uid, watch = watch, expires = CurTime() + 3,
    rate = Number(options.rate, 5, 2, 10),
    related = math.floor(Number(options.related, 16, 1, 64)),
    seconds = Number(options.seconds, 30, 1, 30),
    vision = options.vision == true, signals = options.signals == true, path = options.path == true,
    overview = options.overview == true, next_send = old and old.uid == uid and old.next_send or 0}
  selections[ply] = s
  local vision, signals, expires = false, false, s.expires
  for _, viewer in pairs(selections) do
    if viewer.uid==uid and viewer.expires>CurTime() then
      vision, signals = vision or viewer.vision, signals or viewer.signals
      expires=math.max(expires,viewer.expires)
    end
  end
  I.Subscribe(a, expires, vision, signals)
end, {admin = true})
hook.Add('PlayerDisconnected', 'BGN_Debug_Inspector', function(ply) selections[ply] = nil end)
hook.Add('PostCleanupMap', 'BGN_Debug_Inspector', function() table.Empty(selections) cache = {} end)
hook.Add('SetupPlayerVisibility', 'BGN_Debug_Inspector', function(ply)
  local a, s = Selected(ply)
  if a and s.watch then local eye = I.View(a:GetNPC()) AddOriginToPVS(eye) end
end)
hook.Add('StartCommand', 'BGN_Debug_Inspector', function(ply, cmd)
  local a, s = Selected(ply)
  if a and s.watch then cmd:ClearMovement() cmd:ClearButtons() end
end)
local function Relations(a, list, limit)
  local result = {}
  for _, ent in ipairs(list) do
    if IsValid(ent) and #result < limit then
      result[#result + 1] = {name = I.Name(ent), pos = ent:WorldSpaceCenter(),
        last_seen = a.enemy_last_seen and a.enemy_last_seen[ent] or nil}
    end
  end
  return result
end
local function Snapshot(a, s)
  local npc, brain = a:GetNPC(), a.brain
  local eye, angles = I.View(npc)
  local events, sights, dropped = I.Export(a, s.seconds)
  local weapon = a:GetActiveWeapon()
  local enemies, targets = Relations(a, a.enemies, s.related), Relations(a, a.targets, s.related)
  local path = {}
  if s.path then for j=1,math.min(256,#a.walkPath) do path[j]=a.walkPath[j] end end
  return {
    uid = a.uid, entity = npc, name = I.Name(npc), pos = npc:GetPos(), ang = npc:GetAngles(),
    eye = eye, angles = angles, eye_local = npc:WorldToLocal(eye), aim_local = npc:WorldToLocalAngles(angles),
    mins = npc:OBBMins(), maxs = npc:OBBMaxs(), state = a:GetState(), previous = a:GetOldState(),
    group = a:GetStateGroupName(), reaction = a:GetLastReaction(), hp = a:Health(), max_hp = a:GetMaxHealth(),
    type = a:GetType(), team = table.concat(a.data.team or {}, ', '), lod = a.lod,
    locked = a:IsStateLock(), delay = math.max(0, a.state_delay - CurTime()), wanted = a:IsWanted(),
    staying_out = a:IsStayingOut(), weapon = IsValid(weapon) and weapon:GetClass() or '-',
    brain = bgNPC.Brain.Resolve(a), plan = brain and brain.Describe and brain:Describe() or '',
    damage_weights = a.data.at_damage, protect_weights = a.data.at_protect,
    enemies = enemies, targets = targets, enemy_count = a.enemies_count, target_count = a.targets_count,
    hidden_relations = #a.enemies + #a.targets - #enemies - #targets,
    path = path, hidden_path = s.path and math.max(0,#a.walkPath-#path) or 0,
    destination = a.walkPos, walking = a:Walking(),
    sequence = npc:GetSequenceName(npc:GetSequence()), model = npc:GetModel(), carry = a.carry_item or '-',
    events = events, sights = s.vision and sights or {}, dropped = dropped, time = CurTime(),
    body = a:InVehicle() and 'vehicle' or (npc:IsNextBot() and 'nextbot' or 'npc'),
  }
end
-- One snapshot per UID/options/tick; no debug-only visibility queries.
timer.Create('BGN_Debug_Inspector', 0.1, 0, function()
  cache = {}
  for ply in pairs(selections) do
    local a, s = Selected(ply)
    if not a then
      if IsValid(ply) then bgNPC.Net.Send('bgn.debug_detail', ply, nil) end
    elseif s.next_send <= CurTime() then
      s.next_send = CurTime() + 1 / s.rate
      local start = SysTime()
      local key = a.uid .. ':' .. s.related .. ':' .. s.seconds .. ':' .. tostring(s.path) .. ':' .. tostring(s.vision)
      local d = cache[key]
      if not d then d = Snapshot(a, s) cache[key] = d end
      d.collect_ms = (SysTime() - start) * 1000
      bgNPC.Net.Send('bgn.debug_detail', ply, d)
    end
  end
end)
