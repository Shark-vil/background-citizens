-- Route duplications keep world coordinates, including old SLibrary BGN_NODES duplications.
local Editor = bgNPC.NavEditor
local Net = bgNPC.Net
function Editor.GraphFromDupe(dupe)
  if not istable(dupe) or dupe.id ~= 'BGN_NODES' then return nil, 'not a route duplication' end
  if dupe.map and dupe.map ~= game.GetMap() then return nil, 'route belongs to another map' end
  local data = dupe.data
  if dupe.encoding == 'bgn_graph_base64' then return bgNPC.NodeGraph.Deserialize(isstring(data) and util.Base64Decode(data) or nil) end
  if isstring(data) then data = util.JSONToTable(data, true) end
  if istable(data) and data.format == bgNPC.NodeGraph.FORMAT then return bgNPC.NodeGraph.FromTable(data) end
  return bgNPC.LegacyNodes.ToGraph(data)
end

bgNPC.Test.Add('nav.route_dupe', function(check)
  local graph = bgNPC.NodeGraph()
  local a, b = graph:AddNode(Vector(0, 0, 0)), graph:AddNode(Vector(200, 0, 0))
  graph:Link(a, b, 'walk')
  local copy = Editor.GraphFromDupe({
    id = 'BGN_NODES',
    map = game.GetMap(),
    data = graph:ToTable()
  })

  check(copy and copy:Count() == 2 and copy:IsLinked(1, 2, 'walk'), 'current duplication round trip')
  local old = Editor.GraphFromDupe({
    id = 'BGN_NODES',
    slibrary = true,
    data = util.TableToJSON({
      {
        pos = Vector(0, 0, 0),
        parents = {2}
      },
      {
        pos = Vector(200, 0, 0),
        parents = {1}
      },
    })
  })

  check(old and old:IsLinked(1, 2, 'walk'), 'old SLibrary duplication loads without SLibrary')
  check(Editor.GraphFromDupe({
    id = 'other',
    data = graph:ToTable()
  }) == nil, 'unrelated dupes rejected')

  check(Editor.GraphFromDupe({
    id = 'BGN_NODES',
    map = game.GetMap() .. '_other',
    data = graph:ToTable()
  }) == nil, 'wrong map rejected')
end)

if SERVER then
  local function LoadDupe(ply, dupe)
    if not IsValid(ply) or not (ply:IsAdmin() or ply:IsSuperAdmin()) then return end
    if hook.Run('CanArmDupe', ply) == false then return end
    local graph, err = Editor.GraphFromDupe(dupe)
    if not graph then
      bgNPC.Util.Notify(ply, 'Route was not loaded: ' .. tostring(err), NOTIFY_ERROR)
      return
    end

    bgNPC.Nav.Load('custom', graph)
    Net.Send('bgn_nav_editor_graph', ply, util.Base64Encode(graph:Serialize(), true))
    bgNPC.Util.Notify(ply, 'Route loaded from duplication: ' .. graph:Count() .. ' points', NOTIFY_GENERIC)
  end

  Net.Receive('bgn_route_dupe_load', LoadDupe, {
    admin = true
  })

  -- SLibrary may still be installed alongside other addons.
  hook.Add('OnLoadDuplicator', 'BGN_RouteDupe', function(ply, id, data)
    if id ~= 'BGN_NODES' then return end
    LoadDupe(ply, {
      id = id,
      data = data
    })
    return false
  end)

  bgNPC.Commands.Register('bgn_save_map', {
    admin = true,
    help = 'Saves the active movement graph to your duplications.',
    server = function(ply)
      if not IsValid(ply) then return end
      local provider = bgNPC.Nav.GetProvider()
      if not provider.GetGraph or provider:Count() == 0 then
        bgNPC.Util.Notify(ply, 'No movement graph to save. Generate or load a route first.', NOTIFY_ERROR)
        return
      end

      Net.Send('bgn_route_dupe_save', ply, {
        id = 'BGN_NODES',
        slibrary = true,
        map = game.GetMap(),
        encoding = 'bgn_graph_base64',
        data = util.Base64Encode(provider:GetGraph():Serialize(), true),
      })
    end,
  })
  return
end

-- Register the server command on clients too, for console and spawn menu forwarding.
bgNPC.Commands.Register('bgn_save_map', {
  admin = true
})

local pending
Net.Receive('bgn_route_dupe_save', function(_, dupe) pending = dupe end, {
  admin = true
})

hook.Add('PostRender', 'BGN_SaveRouteDupe', function()
  if not pending then return end
  local dupe = pending
  pending = nil
  local picture = render.Capture({
    format = 'jpg',
    x = 0,
    y = 0,
    w = 512,
    h = 512
  })

  if not picture then
    notification.AddLegacy('Could not capture duplication preview; try saving again', NOTIFY_ERROR, 4)
    return
  end

  local saved = engine.WriteDupe(util.Compress(util.TableToJSON(dupe)), picture)
  notification.AddLegacy(saved and 'Movement graph saved to duplications' or 'Could not save duplication', saved and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
end)

local function LoadRouteDupe(ply, dupe)
  if not istable(dupe) or dupe.id ~= 'BGN_NODES' then return end
  if ply:IsAdmin() or ply:IsSuperAdmin() then Net.SendToServer('bgn_route_dupe_load', dupe) end
  return false
end

hook.Add('OnLoadDuplicator', 'BGN_RouteDupe', function(ply, id, data)
  return LoadRouteDupe(ply, {
    id = id,
    data = data
  })
end)

local function InstallDupeCommand()
  local original = concommand.GetTable().dupe_arm
  if not original or original == Editor.dupe_arm_wrapper then return end
  Editor.dupe_arm_wrapper = function(ply, cmd, args, ...)
    local dupe = args[1] and engine.OpenDupe(args[1])
    local json = dupe and util.Decompress(dupe.data, 5242880)
    local data = json and util.JSONToTable(json, true)
    if istable(data) and data.id == 'BGN_NODES' then
      if hook.Run('CanArmDupe', ply) == false then return end
      LoadRouteDupe(ply, data)
      return
    end
    return original(ply, cmd, args, ...)
  end

  concommand.Add('dupe_arm', Editor.dupe_arm_wrapper)
end

hook.Add('InitPostEntity', 'BGN_RouteDupe', InstallDupeCommand)
hook.Add('OnReloaded', 'BGN_RouteDupe', InstallDupeCommand)
timer.Simple(0, InstallDupeCommand)
