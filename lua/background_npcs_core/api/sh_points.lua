--[[
	bgNPC.Points: movement points and paths for actors (server). Backed by the active navigation
	provider (bgNPC.Nav: navmesh, nodegraph or custom graph).

	Point queries return point objects { position = Vector } with :GetPos(), as the old node objects did.
	On the client the functions return empty results.
--]]
local Assert = bgNPC.Assert
local Points = bgNPC.Points
--
local POINT = {}
POINT.__index = POINT
function POINT:GetPos()
  return self.position
end

local function ToPoint(pos)
  return setmetatable({
    position = pos
  }, POINT)
end

local function ToPoints(positions)
  local list = {}
  for i = 1, #positions do
    list[i] = ToPoint(positions[i])
  end
  return list
end

local function Nav()
  return SERVER and bgNPC.Nav and bgNPC.Nav.GetProvider and bgNPC.Nav or nil
end

-- Radius used by the OUTDATED "chunk" functions.
local CHUNK_RADIUS = 1000
-- ---------------------------------------------------------------------------
-- Point queries
-- ---------------------------------------------------------------------------
function Points.Count()
  local nav = Nav()
  return nav and nav.Count() or 0
end

-- @return table list of points (for the navmesh: a capped sample around the map origin)
function Points.GetAll(link_type)
  local nav = Nav()
  if not nav then return {} end
  return ToPoints(nav.GetAllPoints(link_type))
end

function Points.GetInRadius(center, radius, link_type)
  Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetInRadius')
  Assert.Arg(2, radius, 'number', 'bgNPC.Points.GetInRadius')
  local nav = Nav()
  if not nav then return {} end
  return ToPoints(nav.GetPointsInRadius(center, radius, link_type))
end

-- @return Vector|nil random point (anywhere when center is nil)
function Points.GetRandom(center, radius, link_type)
  local nav = Nav()
  return nav and nav.GetRandomPoint(center, radius or 1500, link_type)
end

local function PickByDistance(points, pos, want_far)
  local result, result_dist
  for i = 1, #points do
    local dist = pos:DistToSqr(points[i].position)
    if not result_dist or (want_far and dist > result_dist) or (not want_far and dist < result_dist) then result, result_dist = points[i], dist end
  end
  return result
end

function Points.GetClosestInRadius(center, radius, link_type)
  Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetClosestInRadius')
  return PickByDistance(Points.GetInRadius(center, radius or 500, link_type), center, false)
end

function Points.GetDistantInRadius(center, radius, link_type)
  Assert.Arg(1, center, 'vector', 'bgNPC.Points.GetDistantInRadius')
  return PickByDistance(Points.GetInRadius(center, radius or 500, link_type), center, true)
end

-- OUTDATED: chunks were removed, these search within 1000 units of center.
function Points.GetIndexesInRadius(center, radius, link_type)
  local indexes = {}
  for i = 1, #Points.GetInRadius(center, radius, link_type) do
    indexes[i] = i
  end
  return indexes
end

function Points.GetClosestInChunk(center, link_type)
  return Points.GetClosestInRadius(center, CHUNK_RADIUS, link_type)
end

function Points.GetDistantInChunk(center, link_type)
  return Points.GetDistantInRadius(center, CHUNK_RADIUS, link_type)
end

function Points.GetClosestToPosInChunk(center, pos, link_type)
  return PickByDistance(Points.GetInRadius(center, CHUNK_RADIUS, link_type), pos, false)
end

function Points.GetDistantToPosInChunk(center, pos, link_type)
  return PickByDistance(Points.GetInRadius(center, CHUNK_RADIUS, link_type), pos, true)
end

-- ---------------------------------------------------------------------------
-- Path finding
-- ---------------------------------------------------------------------------
local DIRECT_DISTANCE_SQR = 500 ^ 2
local PRIMITIVE_POINT_SPACING = 200
local DOOR_SEARCH_RADIUS = 1000
local EYE = Vector(0, 0, 32)
local UP_50 = Vector(0, 0, 50)
local UP_20 = Vector(0, 0, 20)
local DOWN_1000 = Vector(0, 0, 1000)
local world_trace = {
  mask = MASK_NPCWORLDSTATIC
}

local function IsWorldBetween(a, b)
  world_trace.start = a + EYE
  world_trace.endpos = b + EYE
  return util.TraceLine(world_trace).Hit
end

local floor_trace = {
  mask = MASK_NPCWORLDSTATIC
}

local function SnapToFloor(pos)
  floor_trace.start = pos + UP_50
  floor_trace.endpos = pos - DOWN_1000
  return util.TraceLine(floor_trace).HitPos + UP_20
end

-- A point just in front of the door, on the side facing from_pos.
local function GetDoorPassPoint(door, from_pos)
  local min, max = door:GetModelBounds()
  local door_pos = door:LocalToWorld((min + max) / 2)
  local dir = (from_pos - door_pos):GetNormalized()
  local forward, right = door:GetForward(), door:GetRight()
  local forward_dot, right_dot = dir:Dot(forward), dir:Dot(right)
  if math.abs(forward_dot) > math.abs(right_dot) then return door_pos + forward * 20 * (forward_dot > 0 and 1 or -1) end
  return door_pos + right * 20 * (right_dot > 0 and 1 or -1)
end

local function FindDoorBetween(start_pos, end_pos)
  local best, best_dist
  for _, ent in ipairs(ents.FindInSphere(start_pos, DOOR_SEARCH_RADIUS)) do
    if bgNPC.Util.IsDoor(ent) and (bgNPC.Util.IsDoorOpen(ent) or bgNPC.Util.CanActorOpenDoor(ent)) then
      local dist = ent:GetPos():DistToSqr(end_pos)
      if not best_dist or dist < best_dist then best, best_dist = ent, dist end
    end
  end
  return best
end

-- A straight-line path used when the provider has no path (or no points).
-- Routes through the nearest door actors may pass (open, or allowed to open) when a wall is in the way.
local function GetPrimitivePath(start_pos, end_pos)
  local path = {}
  if IsWorldBetween(start_pos, end_pos) then
    local door = FindDoorBetween(start_pos, end_pos)
    if door then
      local door_pos = GetDoorPassPoint(door, start_pos)
      path[#path + 1] = door_pos
      start_pos = door_pos
    end
  end

  local direction = (end_pos - start_pos):GetNormalized()
  local steps = math.floor(start_pos:Distance(end_pos) / PRIMITIVE_POINT_SPACING)
  for i = 1, steps do
    local point = SnapToFloor(start_pos + direction * PRIMITIVE_POINT_SPACING * i)
    if not bgNPC.Util.IsInWorld(point) then break end
    path[#path + 1] = point
  end

  path[#path + 1] = SnapToFloor(end_pos)
  return path
end

--[[
	Finds a walking path between two positions.

	@param start_pos vector
	@param end_pos vector
	@param iteration_limit number|nil OUTDATED, ignored
	@param link_type string|nil walk only over links of this type (graph providers)
	@param actor table|nil the walking actor; bodies that path by themselves get the goal only
	@return table list of positions (never empty)
--]]
function Points.FindPath(start_pos, end_pos, iteration_limit, link_type, actor)
  Assert.Arg(1, start_pos, 'vector', 'bgNPC.Points.FindPath')
  Assert.Arg(2, end_pos, 'vector', 'bgNPC.Points.FindPath')
  Assert.Arg(4, link_type, 'string|nil', 'bgNPC.Points.FindPath')
  if start_pos:DistToSqr(end_pos) <= DIRECT_DISTANCE_SQR and not IsWorldBetween(start_pos, end_pos) then return {end_pos} end
  local nav = Nav()
  if not nav then return {end_pos} end
  if actor and nav.BodyPathsItself(actor.body) then return {end_pos} end
  local path = nav.FindPath(start_pos, end_pos, link_type)
  if not path and link_type then path = nav.FindPath(start_pos, end_pos, nil) end
  return path or GetPrimitivePath(start_pos, end_pos)
end
