-- A bounded NavMesh pocket behind one physical doorway; closed doors are not walls in this search.
local Siege = {}
bgNPC.Siege = Siege
local UP = Vector(0, 0, 48)
local function Area(pos)
  local area = navmesh.GetNearestNavArea(pos, false, 160, false, true)
  if IsValid(area) and math.abs(area:GetClosestPointOnArea(pos).z - pos.z) < 80 then return area end
end

Siege.Area = Area
local function Ceiling(pos)
  local tr = util.TraceLine({
    start = pos + UP,
    endpos = pos + UP + Vector(0, 0, 384),
    mask = MASK_SOLID_BRUSHONLY
  })
  return tr.HitWorld and not tr.HitSky and not tr.StartSolid
end

local function Crosses(portal, a, b)
  local da, db = (a - portal.center):Dot(portal.normal), (b - portal.center):Dot(portal.normal)
  if (da > 0) == (db > 0) or math.abs(da - db) < 0.01 then return false end
  local hit = a + (b - a) * (da / (da - db))
  return math.abs((hit - portal.center):Dot(portal.right)) <= portal.width / 2 + 24 and math.abs(hit.z - portal.floor) < 80
end

-- read by tests/: the physical cut may span several NavMesh connections (and two door leaves).
Siege.Crosses = Crosses
function Siege.Pocket(portal, inside)
  local seed = Area(inside)
  if not seed or not Ceiling(inside) then return end
  local seen, queue, cuts = {
    [seed:GetID()] = true
  }, {seed}, {}

  local head = 1
  while head <= #queue do
    local area = queue[head]
    local pos = area:GetCenter()
    -- shortcut: incomplete NavMeshes cannot prove every escape, decline large/vertical/ladder pockets.
    if #queue > 128 or pos:DistToSqr(portal.center) > 900 ^ 2 or math.abs(pos.z - portal.floor) > 80 or #area:GetLadders() > 0 or not Ceiling(pos) then return end
    local adjacent = area:GetAdjacentAreas()
    table.Add(adjacent, area:GetIncomingConnections())
    for _, next_area in ipairs(adjacent) do
      local id = next_area:GetID()
      if Crosses(portal, pos, next_area:GetCenter()) then
        cuts[id] = true
      elseif not seen[id] then
        seen[id] = true
        queue[#queue + 1] = next_area
      end
    end

    head = head + 1
  end

  if next(cuts) == nil then return end
  for id in pairs(cuts) do -- another way around the same doorway
    if seen[id] then return end
  end
  return seen
end

local function DoorPortal(door, doors)
  local center, normal, size = bgNPC.Doors.Geometry(door)
  if not center then return end
  local right = normal:Cross(Vector(0, 0, 1))
  local width = math.max(size.x, size.y)
  local low, high, leaves = -width / 2, width / 2, {door}
  local key = door:EntIndex()
  for _, other in ipairs(doors) do
    if other ~= door then
      local c, n, s = bgNPC.Doors.Geometry(other)
      if c and math.abs(n:Dot(normal)) > 0.99 and math.abs((c - center):Dot(normal)) < 8 and math.abs(c.z - center.z) < 8 then
        local offset, half = (c - center):Dot(right), math.max(s.x, s.y) / 2
        if offset - half <= high + 8 and offset + half >= low - 8 then
          low, high = math.min(low, offset - half), math.max(high, offset + half)
          leaves[#leaves + 1] = other
          key = math.min(key, other:EntIndex())
        end
      end
    end
  end

  center = center + right * ((low + high) / 2)
  return {
    key = 'door:' .. key,
    center = center,
    normal = normal,
    right = right,
    width = high - low,
    floor = center.z - size.z / 2,
    doors = leaves
  }
end

-- A narrow, walled NavMesh portal also supports passages without a door entity.
local function OpenPortal(a, b)
  local amin, amax, bmin, bmax = a:GetCorner(0), a:GetCorner(2), b:GetCorner(0), b:GetCorner(2)
  local axis, low, high, plane
  if math.abs(amax.x - bmin.x) < 2 or math.abs(bmax.x - amin.x) < 2 then
    axis, low, high = 'x', math.max(amin.y, bmin.y), math.min(amax.y, bmax.y)
    plane = math.abs(amax.x - bmin.x) < 2 and amax.x or amin.x
  elseif math.abs(amax.y - bmin.y) < 2 or math.abs(bmax.y - amin.y) < 2 then
    axis, low, high = 'y', math.max(amin.x, bmin.x), math.min(amax.x, bmax.x)
    plane = math.abs(amax.y - bmin.y) < 2 and amax.y or amin.y
  end

  if not axis or high <= low then return end
  local floor = (a:GetCenter().z + b:GetCenter().z) / 2
  if math.abs(a:GetCenter().z - b:GetCenter().z) > 24 then return end
  local center = axis == 'x' and Vector(plane, (low + high) / 2, floor + 48) or Vector((low + high) / 2, plane, floor + 48)
  local normal = axis == 'x' and Vector(1, 0, 0) or Vector(0, 1, 0)
  local right = normal:Cross(Vector(0, 0, 1))
  local walls = {}
  for _, sign in ipairs({-1, 1}) do
    local tr = util.TraceLine({
      start = center,
      endpos = center + right * sign * 160,
      mask = MASK_SOLID_BRUSHONLY
    })

    if not tr.HitWorld or tr.StartSolid or math.abs(tr.HitNormal:Dot(right)) < 0.7 then return end
    walls[sign] = tr.HitPos:Distance(center)
  end

  local width = walls[-1] + walls[1]
  if width < 32 or width > 128 then return end
  center = center + right * ((walls[1] - walls[-1]) / 2)
  local floor_center = Vector(center.x, center.y, floor + 2)
  local hull = util.TraceHull({
    start = floor_center - normal * 32,
    endpos = floor_center + normal * 32,
    mins = Vector(-16, -16, 0),
    maxs = Vector(16, 16, 36),
    mask = MASK_NPCSOLID_BRUSHONLY
  })

  if hull.Hit or hull.StartSolid then return end
  return {
    key = 'nav:' .. math.min(a:GetID(), b:GetID()) .. ':' .. math.max(a:GetID(), b:GetID()),
    center = center,
    normal = normal,
    right = right,
    width = width,
    floor = floor,
    doors = {}
  }
end

local function FindPocket(candidates, known)
  table.sort(candidates, function(a, b) return a.center:DistToSqr(known) < b.center:DistToSqr(known) end)
  for i = 1, math.min(12, #candidates) do
    local portal = candidates[i]
    local inside = (known - portal.center):Dot(portal.normal) > 0 and 1 or -1
    portal.normal = portal.normal * -inside -- points outside
    portal.right = portal.normal:Cross(Vector(0, 0, 1))
    portal.pocket = Siege.Pocket(portal, known)
    if portal.pocket then return portal end
    -- The target vanished next to the doorway: it may have gone through, so also try the far side as the pocket.
    if (known - portal.center):LengthSqr() < 300 ^ 2 then
      portal.normal = -portal.normal
      portal.right = portal.normal:Cross(Vector(0, 0, 1))
      local seed = portal.center - portal.normal * 96
      seed.z = portal.floor + 2
      portal.pocket = Siege.Pocket(portal, seed)
      if portal.pocket then return portal end
    end
  end
end

local cache = setmetatable({}, {
  __mode = 'k'
})

local next_search = 0
function Siege.Find(enemy, known)
  if not navmesh.IsLoaded() or not known then return end
  local saved = cache[enemy]
  if saved and saved.until_time > CurTime() and saved.pos:DistToSqr(known) < 96 ^ 2 then return saved.portal end
  if next_search > CurTime() then return end
  next_search = CurTime() + 0.25
  local doors, candidates, keys = {}, {}, {}
  for _, ent in ipairs(ents.FindInSphere(known, 700)) do
    if bgNPC.Util.IsDoor(ent) then doors[#doors + 1] = ent end
  end

  for _, door in ipairs(doors) do
    local portal = DoorPortal(door, doors)
    if portal and not keys[portal.key] then
      keys[portal.key] = true
      candidates[#candidates + 1] = portal
    end
  end

  local found = FindPocket(candidates, known)
  if not found then
    candidates = {}
    for i, area in ipairs(navmesh.Find(known, 600, 64, 64)) do
      if i > 64 then break end
      for _, adjacent in ipairs(area:GetAdjacentAreas()) do
        local portal = OpenPortal(area, adjacent)
        if portal and not keys[portal.key] then
          keys[portal.key] = true
          candidates[#candidates + 1] = portal
        end
      end

      if #candidates >= 24 then break end
    end

    found = FindPocket(candidates, known)
  end

  cache[enemy] = {
    pos = known,
    portal = found,
    until_time = CurTime() + 3
  }
  return found
end

hook.Add('BGN_NavProviderChanged', 'BGN_SiegePortals', function()
  cache = setmetatable({}, {
    __mode = 'k'
  })
end)

hook.Add('PreCleanupMap', 'BGN_SiegePortals', function()
  cache = setmetatable({}, {
    __mode = 'k'
  })
end)
