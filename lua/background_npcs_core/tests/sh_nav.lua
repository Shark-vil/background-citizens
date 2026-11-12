local AStar = bgNPC.AStar
local Heap = AStar.Heap
local NodeGraph = bgNPC.NodeGraph
local LegacyNodes = bgNPC.LegacyNodes
local Editor = bgNPC.NavEditor

bgNPC.Test.Add('nav.heap', function(check)
  local heap = Heap()
  for _, v in ipairs({5, 1, 9, 3, 7, 2, 8}) do
    heap:Push('k' .. v, v)
  end

  local out = {}
  while not heap:IsEmpty() do
    local _, p = heap:Pop()
    out[#out + 1] = p
  end

  check(table.concat(out, ',') == '1,2,3,5,7,8,9', 'heap pops in order: ' .. table.concat(out, ','))
end)

bgNPC.Test.Add('nav.astar.grid', function(check)
  -- 10x10 grid with a wall at x = 5 (gap at y = 9)
  local function id(x, y)
    return y * 10 + x
  end

  local function xy(i)
    return i % 10, math.floor(i / 10)
  end

  local function blocked(x, y)
    return x == 5 and y ~= 9
  end

  local path = AStar.Search({
    start = id(0, 0),
    is_goal = function(i) return i == id(9, 0) end,
    heuristic = function(i)
      local x, y = xy(i)
      return math.abs(9 - x) + math.abs(y)
    end,
    neighbours = function(i, push)
      local x, y = xy(i)
      for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        local nx, ny = x + d[1], y + d[2]
        if nx >= 0 and nx < 10 and ny >= 0 and ny < 10 and not blocked(nx, ny) then push(id(nx, ny), 1) end
      end
    end,
  })

  check(path ~= nil, 'path found')
  check(path and #path == 28, 'shortest path length 28, got ' .. tostring(path and #path))
  local none = AStar.Search({
    start = 1,
    is_goal = function(i) return i == 99 end,
    heuristic = function() return 0 end,
    neighbours = function() end,
  })

  check(none == nil, 'no path returns nil')
end)

bgNPC.Test.Add('nav.large_round_trip', function(check)
  local graph = NodeGraph()
  for i = 1, 6002 do
    graph:AddNode(Vector(i + 0.125, i % 10 + 0.0625, -0.03125))
    if i > 1 then graph:Link(i - 1, i, 'walk') end
  end

  local data = graph:ToTable()
  check(#data.nodes > 15000 and #data.links > 15000, 'both arrays exceed engine JSON limits')
  local copy = NodeGraph.Deserialize(graph:Serialize())
  check(copy and copy:Count() == 6002 and copy:LinksCount() == 6001, 'large graph counts survive serialization')
  if copy then
    for i = 1, 6002 do
      check(copy:GetPos(i) == graph:GetPos(i), 'point ' .. i .. ' keeps its coordinates')
    end

    for i = 1, 6001 do
      check(copy:IsLinked(i, i + 1, 'walk'), 'walk link ' .. i .. ' survives')
    end
  end

  table.remove(data.links)
  table.remove(data.links)
  table.remove(data.links)
  check(NodeGraph.FromTable(data) == nil, 'truncation of whole link triples is rejected')
end)

bgNPC.Test.Add('nav.node_graph', function(check)
  local g = NodeGraph(256)
  local ids = {}
  for i = 0, 9 do
    ids[i] = g:AddNode(Vector(i * 200, 0, 0))
  end

  for i = 0, 8 do
    g:Link(ids[i], ids[i + 1], 'walk')
  end

  g:Link(ids[0], ids[9]) -- plain neighbour link, not walkable
  check(g:Count() == 10 and g:LinksCount() == 10, 'counts')
  check(g:IsLinked(ids[0], ids[9]) and not g:IsLinked(ids[0], ids[9], 'walk'), 'typed link mask')
  local walk = g:FindPath(ids[0], ids[9], 'walk')
  check(walk and #walk == 10, 'walk path goes through all nodes')
  local any = g:FindPath(ids[0], ids[9])
  check(any and #any == 2, 'untyped path uses the shortcut')
  check(#g:GetInRadius(Vector(0, 0, 0), 450) == 3, 'radius query')
  check(g:FindNearest(Vector(390, 10, 0), 1000) == ids[2], 'nearest')
  g:RemoveNode(ids[5])
  check(g:FindPath(ids[0], ids[9], 'walk') == nil, 'removed node breaks the walk path')
  check(not g:IsLinked(ids[4], ids[5]), 'links of removed node are gone')
  local copy = NodeGraph.Deserialize(g:Serialize(), 256)
  check(g.max_id == 10 and g:Exists(ids[9]) and not g:Exists(ids[5]), 'serialization keeps live ids and holes')
  check(copy and copy:Count() == 9 and copy:LinksCount() == 8, 'serialize round trip')
  check(copy and copy:FindPath(1, 5, 'walk') ~= nil, 'paths survive compaction')
  local moved = NodeGraph(256)
  local m1, m2 = moved:AddNode(Vector(0, 0, 0)), moved:AddNode(Vector(100, 0, 0))
  moved:Link(m1, m2, 'walk')
  moved:SetPos(m1, Vector(5000, 0, 0))
  check(moved:IsLinked(m1, m2, 'walk') and moved:FindNearest(Vector(5000, 0, 0), 10) == m1, 'SetPos keeps links')
end)

bgNPC.Test.Add('nav.legacy_convert', function(check)
  local json = util.TableToJSON({
    version = '1.2',
    nodes = {
      {
        position = Vector(0, 0, 0),
        parents = {2},
        links = {
          walk = {2}
        }
      },
      {
        position = Vector(100, 0, 0),
        parents = {1, 3},
        links = {
          walk = {1}
        }
      },
      {
        position = Vector(200, 0, 0),
        parents = {2},
        links = {}
      },
    },
  })

  local graph = LegacyNodes.ToGraph(json)
  check(graph and graph:Count() == 3, 'three nodes')
  check(graph and graph:IsLinked(1, 2, 'walk') and graph:IsLinked(2, 3) and not graph:IsLinked(2, 3, 'walk'), 'parents become plain links, walk links keep the type')
  check(LegacyNodes.ToGraph('garbage') == nil, 'garbage is rejected')
  for _, version in ipairs({'1.0', '1.1', '1.2'}) do
    local copy = LegacyNodes.ToGraph({
      version = version,
      nodes = {
        {
          position = '[0 0 0]',
          parents = {2}
        },
        {
          position = '[200 0 0]',
          parents = {1}
        },
      }
    })

    check(copy and copy:IsLinked(1, 2, version == '1.0' and 'walk' or nil), version .. ' converts')
  end

  local oldest = LegacyNodes.ToGraph({
    {
      pos = Vector(0, 0, 0),
      parents = {2}
    },
    {
      pos = Vector(200, 0, 0),
      parents = {1}
    },
  })

  check(oldest and oldest:IsLinked(1, 2, 'walk'), 'unversioned pos/parents stays walkable')
  check(LegacyNodes.ToGraph({
    version = '1.2',
    nodes = {
      {
        position = 'garbage'
      }
    }
  }) == nil, 'invalid positions are rejected instead of becoming the origin')
end)

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
