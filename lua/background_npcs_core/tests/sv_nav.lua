local NodegraphProvider = bgNPC.Nav.NodegraphProvider
-- .ain format constants, as in nav/providers/sv_nodegraph_provider.lua
local AIN_VERSION = 37
local NUM_HULLS = 10
local NODE_GROUND = 2
local MOVE_GROUND = 1

-- In-memory little endian writer/reader for the parser test.
local function Buffer()
  local b = {
    data = {},
    pos = 1
  }

  function b:WriteRaw(fmt_bytes)
    for _, v in ipairs(fmt_bytes) do
      self.data[#self.data + 1] = v
    end
  end

  local function int_bytes(v, n)
    local out = {}
    if v < 0 then v = v + 2 ^ (8 * n) end
    for i = 1, n do
      out[i] = v % 256
      v = math.floor(v / 256)
    end
    return out
  end

  function b:Long(v)
    self:WriteRaw(int_bytes(v, 4))
  end

  function b:Short(v)
    self:WriteRaw(int_bytes(v, 2))
  end

  function b:Byte(v)
    self:WriteRaw({v})
  end

  function b:Float(v)
    -- IEEE 754 single for small integers/zero, enough for the test
    if v == 0 then
      self:Long(0)
      return
    end

    local sign = v < 0 and 1 or 0
    v = math.abs(v)
    local exp = math.floor(math.log(v, 2))
    local mant = v / 2 ^ exp - 1
    self:Long(sign * 2 ^ 31 + (exp + 127) * 2 ^ 23 + math.floor(mant * 2 ^ 23 + 0.5))
  end

  local function read(self, n, signed)
    local v = 0
    for i = n, 1, -1 do
      v = v * 256 + self.data[self.pos + i - 1]
    end

    self.pos = self.pos + n
    if signed and v >= 2 ^ (8 * n - 1) then v = v - 2 ^ (8 * n) end
    return v
  end

  function b:ReadLong()
    return read(self, 4, true)
  end

  function b:ReadShort()
    return read(self, 2, true)
  end

  function b:ReadUShort()
    return read(self, 2, false)
  end

  function b:ReadByte()
    return read(self, 1, false)
  end

  function b:ReadFloat()
    local v = read(self, 4, false)
    if v == 0 then return 0 end
    local sign = v >= 2 ^ 31 and -1 or 1
    local exp = math.floor(v / 2 ^ 23) % 256 - 127
    local mant = (v % 2 ^ 23) / 2 ^ 23 + 1
    return sign * mant * 2 ^ exp
  end
  return b
end

bgNPC.Test.Add('nav.ain_parser', function(check)
  local b = Buffer()
  b:Long(AIN_VERSION)
  b:Long(1)
  b:Long(3)
  local nodes = {{0, 0, 0, NODE_GROUND}, {128, 0, 0, NODE_GROUND}, {0, 256, 0, 3}}
  for _, n in ipairs(nodes) do
    b:Float(n[1])
    b:Float(n[2])
    b:Float(n[3])
    b:Float(0)
    for _ = 1, NUM_HULLS do
      b:Float(0)
    end

    b:Byte(n[4])
    b:Short(0)
    b:Short(0)
  end

  b:Long(2)
  b:Short(0)
  b:Short(1)
  for hull = 1, NUM_HULLS do
    b:Byte(hull == 1 and MOVE_GROUND or 0)
  end

  b:Short(1)
  b:Short(2)
  for _ = 1, NUM_HULLS do
    b:Byte(MOVE_GROUND)
  end

  local graph = NodegraphProvider.Parse(b)
  check(graph and graph:Count() == 2, 'only ground nodes are kept')
  check(graph and graph:IsLinked(1, 2, 'walk'), 'ground link for the human hull')
  check(graph and graph:GetPos(2) == Vector(128, 0, 0), 'node position')
  local bad = Buffer()
  bad:Long(36)
  check(NodegraphProvider.Parse(bad) == nil, 'wrong version is rejected')
end)
