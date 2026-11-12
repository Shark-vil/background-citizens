--[[
	NodegraphProvider: the map's AI node graph (maps/graphs/<map>.ain, format version 37).

	.ain layout (little endian):
		int version, int map_version, int node_count
		node: float x, y, z, float yaw, float offsets[10], byte type, ushort info, short zone
		int link_count
		link: short src, short dest, byte moves[10]
		int lookup[node_count]
	Only ground nodes (type 2) and links walkable by the human hull (moves[1] has the ground bit) are used.
--]]
local Nav = bgNPC.Nav
local NodeGraph = bgNPC.NodeGraph
local NodegraphProvider = bgNPC.Class('BGN_NodegraphProvider', Nav.GraphProvider)
Nav.NodegraphProvider = NodegraphProvider
local AIN_VERSION = 37
local NUM_HULLS = 10
local NODE_GROUND = 2
local MOVE_GROUND = 1
local HULL_HUMAN = 1 -- 1-based index into moves
local function AinPath()
  return 'maps/graphs/' .. game.GetMap() .. '.ain'
end

-- Parses an .ain file. reader has ReadLong/ReadFloat/ReadByte/ReadShort/ReadUShort.
-- @return NodeGraph|nil, string|nil error
function NodegraphProvider.Parse(reader)
  local version = reader:ReadLong()
  if version ~= AIN_VERSION then return nil, 'unsupported .ain version ' .. tostring(version) end
  reader:ReadLong() -- map version
  local node_count = reader:ReadLong()
  if not node_count or node_count < 0 or node_count > 65536 then return nil, 'bad node count' end
  local graph = NodeGraph()
  local ids = {}
  for i = 0, node_count - 1 do
    local x, y, z = reader:ReadFloat(), reader:ReadFloat(), reader:ReadFloat()
    reader:ReadFloat() -- yaw
    for _ = 1, NUM_HULLS do
      reader:ReadFloat()
    end

    local node_type = reader:ReadByte()
    reader:ReadUShort() -- info
    reader:ReadShort() -- zone
    if node_type == NODE_GROUND then ids[i] = graph:AddNode(Vector(x, y, z)) end
  end

  local link_count = reader:ReadLong() or 0
  for _ = 1, link_count do
    local src, dest = reader:ReadShort(), reader:ReadShort()
    local human_moves
    for hull = 1, NUM_HULLS do
      local moves = reader:ReadByte()
      if hull == HULL_HUMAN then human_moves = moves end
    end

    local a, b = ids[src], ids[dest]
    if a and b and human_moves and bit.band(human_moves, MOVE_GROUND) ~= 0 then graph:Link(a, b, 'walk') end
  end
  return graph
end

function NodegraphProvider.IsAvailable()
  return file.Exists(AinPath(), 'GAME')
end

function NodegraphProvider.HasSavedRoute()
  return false
end

function NodegraphProvider:Load()
  local f = file.Open(AinPath(), 'rb', 'GAME')
  if not f then return false, 'no .ain file' end
  local ok, graph, err = pcall(NodegraphProvider.Parse, f)
  f:Close()
  if not ok then return false, graph end
  if not graph then return false, err end
  -- Isolated nodes are useless for walking
  for id in graph:Nodes() do
    if not graph:HasLinks(id) then graph:RemoveNode(id) end
  end

  self.graph = graph
  return true
end
