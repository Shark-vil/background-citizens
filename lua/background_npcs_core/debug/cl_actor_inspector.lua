local Inspector = bgNPC.DebugInspector
local Net = bgNPC.Net
if Inspector.RestoreViewBody then Inspector.RestoreViewBody() end
Inspector.rows = {}
Inspector.uid, Inspector.detail, Inspector.watching = nil, nil, false
local received_at, next_request = 0, 0
local function Text(key)
  key = 'bgn.debug.' .. key
  return bgNPC.Phrases and bgNPC.Phrases[key] or language.GetPhrase(key)
end

local function Allowed()
  local ply = LocalPlayer()
  return GetConVar('bgn_debug'):GetBool() and IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

local function Options()
  local function B(n)
    return GetConVar('bgn_cl_debug_' .. n):GetBool()
  end

  local function N(n)
    return GetConVar('bgn_cl_debug_' .. n):GetFloat()
  end
  return {
    rate = N('rate'),
    related = N('related'),
    seconds = N('seconds'),
    vision = B('vision'),
    signals = B('signals'),
    path = GetConVar('bgn_cl_draw_npc_path'):GetBool(),
    overview = B('overview')
  }
end

local function Select(uid, watch)
  Inspector.uid, Inspector.detail, Inspector.live_detail, Inspector.watching = uid, nil, nil, watch or false
  if Inspector.ResetVisuals then Inspector.ResetVisuals() end
  next_request, received_at = RealTime() + 1, RealTime()
  Net.SendToServer('bgn.debug_select', uid, Inspector.watching, Options())
end

local function SelectAimed()
  if not Allowed() then return end
  local actor = bgNPC.Actors.Get(LocalPlayer():GetEyeTrace().Entity)
  if actor then
    Select(actor.uid)
  else
    notification.AddLegacy(Text('aim.help'), NOTIFY_HINT, 4)
  end
end

concommand.Add('bgn_debug_select', function(_, _, args)
  if not Allowed() then return end
  if args[1] then
    Select(tonumber(args[1]))
  else
    SelectAimed()
  end
end)

concommand.Add('bgn_debug_clear', function() Select(nil) end)
concommand.Add('bgn_debug_watch_stop', function() if Inspector.uid then Select(Inspector.uid, false) end end)
concommand.Add('bgn_debug_watch', function()
  if not Allowed() then return end
  if not Inspector.uid then SelectAimed() end
  if Inspector.uid then Select(Inspector.uid, not Inspector.watching) end
end)

Net.Receive('bgn.debug_detail', function(_, detail)
  if not Allowed() or not detail then
    Select(nil)
    return
  end

  if detail.uid ~= Inspector.uid then return end
  Inspector.live_detail, received_at = detail, RealTime()
  if not GetConVar('bgn_cl_debug_freeze'):GetBool() or not Inspector.detail then
    Inspector.detail = detail
    if Inspector.OnSnapshot then Inspector.OnSnapshot(detail) end
  end
end)

hook.Add('Think', 'BGN_Debug_Inspector', function()
  if not Inspector.uid then return end
  if not Allowed() or RealTime() - received_at > 3 then
    Select(nil)
    return
  end

  if Inspector.watching and (not LocalPlayer():Alive() or input.IsKeyDown(KEY_F6) or gui.IsGameUIVisible()) then
    Select(Inspector.uid, false)
  elseif next_request <= RealTime() then
    next_request = RealTime() + 1
    Net.SendToServer('bgn.debug_select', Inspector.uid, Inspector.watching, Options())
  end
end)

cvars.AddChangeCallback('bgn_debug', function() Select(nil) end, 'BGN_Debug_Inspector')
hook.Add('PostCleanupMap', 'BGN_Debug_Inspector', function()
  Select(nil)
  Inspector.rows = {}
end)

local function Watching()
  return Inspector.watching and Allowed() and Inspector.detail and RealTime() - received_at < 2
end

Inspector.IsWatching = Watching
local view_body, view_render, previous_render
function Inspector.RestoreViewBody()
  if IsValid(view_body) and view_body.RenderOverride == view_render then view_body.RenderOverride = previous_render end
  view_body, view_render, previous_render = nil, nil, nil
end

hook.Add('PreRender', 'BGN_Debug_CameraBody', function()
  local active = Inspector.live_detail or Inspector.detail
  local body = Watching() and active.entity
  if not IsValid(body) then
    Inspector.RestoreViewBody()
    return
  end

  if body == view_body and body.RenderOverride == view_render then return end
  Inspector.RestoreViewBody()
  local original = body.RenderOverride
  view_body, previous_render = body, original
  view_render = function(ent)
    if Watching() and (Inspector.live_detail or Inspector.detail).entity == ent then return end
    if original then return original(ent) end
    ent:DrawModel()
  end

  body.RenderOverride = view_render
end)

hook.Add('CalcView', 'BGN_Debug_Inspector', function(_, _, _, fov)
  if not Watching() then return end
  local detail = Inspector.live_detail or Inspector.detail
  local eye, angles = detail.eye, detail.angles
  if IsValid(detail.entity) and not detail.entity:IsDormant() and detail.eye_local and detail.aim_local then eye, angles = Inspector.View(detail.entity, detail) end
  return {
    origin = eye + angles:Forward() * 8,
    angles = angles,
    fov = fov,
    znear = 1,
    drawviewer = true
  }
end)

hook.Add('CreateMove', 'BGN_Debug_Inspector', function(cmd)
  if Watching() then
    cmd:ClearMovement()
    cmd:ClearButtons()
  end
end)

hook.Add('PreDrawViewModel', 'BGN_Debug_Inspector', function() if Watching() then return true end end)
hook.Add('HUDShouldDraw', 'BGN_Debug_Inspector', function(name) if Watching() and name == 'CHudCrosshair' then return false end end)
Inspector.Select = Select
Inspector.Text = Text
Inspector.Allowed = Allowed
Inspector.Options = Options
concommand.Add('bgn_debug_pin', function() Inspector.pinned = not Inspector.pinned end)
concommand.Add('bgn_debug_freeze', function() RunConsoleCommand('bgn_cl_debug_freeze', GetConVar('bgn_cl_debug_freeze'):GetBool() and '0' or '1') end)
bgNPC.Net.Receive('bgn.debug_roster', function(_, rows, dropped)
  if Allowed() then
    Inspector.rows, Inspector.roster_dropped = rows, dropped or 0
    Inspector.roster_serial = (Inspector.roster_serial or 0) + 1
  end
end)

function Inspector.RequestRoster()
  if Allowed() then Net.SendToServer('bgn.debug_roster') end
end

function Inspector.BuildPanel(panel)
  panel:ClearControls()
  local ply = LocalPlayer()
  if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then
    panel:Help(Text('admin'))
    return
  end

  panel:Help(Text('workspace.help'))
  panel:CheckBox(Text('enable'), 'bgn_debug')
  local combo = panel:ComboBox(Text('actor'))
  local roster_status = panel:Help('')
  local function Fill()
    combo:Clear()
    for _, row in ipairs(Inspector.rows) do
      combo:AddChoice(row.type .. ' #' .. row.uid .. ' | ' .. (Inspector.State and Inspector.State(row.state) or row.state), row.uid, row.uid == Inspector.uid)
    end

    roster_status:SetText(Text('actor') .. ': ' .. #Inspector.rows .. ((Inspector.roster_dropped or 0) > 0 and (' | ' .. Text('limited') .. ': ' .. Inspector.roster_dropped) or ''))
  end

  combo.OnSelect = function(_, _, _, uid) if Allowed() and uid ~= Inspector.uid then Select(uid) end end
  panel:Button(Text('refresh')).DoClick = function()
    Inspector.RequestRoster()
    Fill()
  end

  Inspector.RequestRoster()
  Fill()
  local serial = Inspector.roster_serial or 0
  combo.Think = function()
    if serial ~= (Inspector.roster_serial or 0) then
      serial = Inspector.roster_serial or 0
      Fill()
    end
  end

  for _, key in ipairs({'aim', 'details', 'watch', 'watch_stop', 'clear', 'pin', 'freeze'}) do
    panel:Button(Text(key), 'bgn_debug_' .. (key == 'aim' and 'select' or key))
  end

  local mode = panel:ComboBox(Text('mode'), 'bgn_cl_debug_mode')
  for j = 0, 2 do
    mode:AddChoice(Text('mode.' .. j), j)
  end

  panel:NumSlider(Text('text_scale'), 'bgn_cl_debug_text_scale', .75, 2, 2)
  for _, pair in ipairs({{'inspector', 'inspector'}, {'summary', 'summary'}, {'bounds', 'bounds'}, {'labels', 'labels'}, {'paths', 'draw_npc_path'}, {'target_lines', 'targets'}, {'vision', 'vision'}, {'signals', 'signals'}, {'history', 'history'}}) do
    panel:CheckBox(Text(pair[1]), pair[2] == 'draw_npc_path' and 'bgn_cl_draw_npc_path' or 'bgn_cl_debug_' .. pair[2])
  end

  panel:NumSlider(Text('distance'), 'bgn_cl_debug_distance', 100, 5000, 0)
  panel:NumSlider(Text('geometry_distance'), 'bgn_cl_debug_geometry_distance', 100, 5000, 0)
  local advanced = vgui.Create('DForm', panel)
  advanced:SetName(Text('advanced'))
  advanced:SetExpanded(false)
  panel:AddItem(advanced)
  for _, setting in ipairs(bgNPC.debug_settings) do
    local name, kind = setting[1], setting[2]
    if name ~= 'mode' and name ~= 'signals' and name ~= 'distance' and name ~= 'geometry_distance' and name ~= 'freeze' then
      if kind == 'check' then
        advanced:CheckBox(Text(name), 'bgn_cl_debug_' .. name)
      elseif kind == 'number' then
        advanced:NumSlider(Text(name), 'bgn_cl_debug_' .. name, setting[4], setting[5], name == 'life' and 1 or 0)
      elseif kind == 'text' then
        advanced:TextEntry(Text(name), 'bgn_cl_debug_' .. name)
      end
    end
  end

  panel:Help(Text('legend'))
  panel:Help(Text('vision.help'))
  panel:Help(Text('watch.help'))
end

hook.Add('PopulateToolMenu', 'BGN_Debug_Inspector', function() spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Debug', Text('title'), '', '', Inspector.BuildPanel) end)
