--[[
	Scenic spots: finds a place that fits a scene (bgNPC.cfg.scenic, config/states/sh_scenic.lua).

	A seed is a cheap candidate: a walkable point for the floor, sky and wall scenes, an entity for the door and
	chair scenes. A finder turns a seed into a spot { pos, ang, ... } or rejects it; the traces are spent
	on the seeds that passed the cheap checks only. The entity index is cached, so a map is not scanned per try.

		Spots.Seeds(place, players) -> list of seeds, nearest to the ring around the players first
		Spots.Find(place, seed)     -> spot | nil
--]]
local Scenic = bgNPC.Scenic or {}
bgNPC.Scenic = Scenic
local Spots = {}
Scenic.Spots = Spots
local function Shuffle(t)
  return Spots.preview and table.Copy(t) or bgNPC.Table.Shuffle(t)
end

--
local INDEX_LIFETIME = 30
local DOOR_CLASSES = {'prop_door_rotating', 'func_door_rotating'}
local MAX_SEEDS = 24
local UP_STEP = Vector(0, 0, 36)
local DOWN = Vector(0, 0, -64)
local WALL_DIRECTIONS = {Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0)}
local cvar_radius = GetConVar('bgn_spawn_radius')
local cvar_block = GetConVar('bgn_spawn_block_radius')
-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- @return Vector|nil, table the walkable floor under the point and its trace
local function Floor(pos)
  local tr = util.TraceLine({
    start = pos + UP_STEP,
    endpos = pos + DOWN,
    mask = MASK_SOLID_BRUSHONLY
  })

  if not tr.Hit or tr.StartSolid or tr.HitNormal.z < 0.95 then return end
  return tr.HitPos, tr
end

Spots.Floor = Floor
-- Reject outdoor courtyards and roofs: a room needs a nearby solid ceiling and walls on every side.
function Spots.InRoom(pos)
  local from = pos + Vector(0, 0, 48)
  for _, dir in ipairs({Vector(0, 0, 1), Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0)}) do
    local tr = util.TraceLine({
      start = from,
      endpos = from + dir * (dir.z == 1 and 384 or 512),
      mask = MASK_SOLID_BRUSHONLY
    })

    if not tr.Hit or tr.HitSky or tr.StartSolid or not tr.HitWorld then return false end
    if dir.z == 1 and tr.HitNormal.z > -0.7 then return false end
    if dir.z == 0 and math.abs(tr.HitNormal.z) > 0.2 then return false end
  end
  return true
end

local prop_bounds = {}
function Spots.PropFits(model, pos, ang)
  local bounds = prop_bounds[model]
  if not bounds then
    local probe = ents.Create('prop_dynamic')
    if not IsValid(probe) then return false end
    probe:SetModel(model)
    local mins, maxs = probe:GetModelBounds()
    probe:Remove()
    bounds = {mins, maxs}
    prop_bounds[model] = bounds
  end

  local mins, maxs = bounds[1], bounds[2]
  local half, center = (maxs - mins) * 0.5, (maxs + mins) * 0.5
  local forward, right = ang:Forward(), ang:Right()
  local extent = Vector(math.abs(forward.x) * half.x + math.abs(right.x) * half.y, math.abs(forward.y) * half.x + math.abs(right.y) * half.y, half.z)
  local origin = pos + forward * center.x - right * center.y + Vector(0, 0, center.z + 1)
  local tr = util.TraceHull({
    start = origin,
    endpos = origin,
    mins = -extent,
    maxs = extent,
    mask = MASK_SOLID_BRUSHONLY
  })
  return not tr.Hit and not tr.StartSolid
end

-- Room for a standing body (brushes only, props are the spawner's business).
function Spots.HasRoom(pos)
  local tr = util.TraceHull({
    start = pos + Vector(0, 0, 2),
    endpos = pos + Vector(0, 0, 2),
    mins = Vector(-16, -16, 0),
    maxs = Vector(16, 16, 70),
    mask = MASK_SOLID_BRUSHONLY,
  })
  return not tr.StartSolid and not tr.Hit
end

-- At least `min` and at most `max` units from some player.
local function InRing(pos, players, min, max)
  local min_sqr, max_sqr = min * min, max * max
  for i = 1, #players do
    local dist = pos:DistToSqr(players[i]:GetPos())
    if dist >= min_sqr and dist <= max_sqr then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------
-- Entity index
-- ---------------------------------------------------------------------------
local index = {
  doors = {
    time = 0
  },
  chairs = {
    time = 0
  }
}

local function ChairModels()
  local set = {}
  for _, data in ipairs(bgNPC.cfg.sit_chairs) do
    for _, model in ipairs(data.models) do
      set[model:lower()] = data
    end
  end
  return set
end

local function Refresh(kind)
  local entry = index[kind]
  if entry.list and entry.time + INDEX_LIFETIME > CurTime() then -- no list yet: CurTime() < INDEX_LIFETIME at map start
    return entry.list
  end

  local list = {}
  if kind == 'doors' then
    for _, class in ipairs(DOOR_CLASSES) do
      for _, ent in ipairs(ents.FindByClass(class)) do
        list[#list + 1] = ent
      end
    end
  else
    local models = ChairModels()
    for _, ent in ipairs(ents.FindByClass('prop_*')) do
      if models[(ent:GetModel() or ''):lower()] then list[#list + 1] = ent end
    end

    for _, seat in ipairs(BGN_SEAT:GetAllSeats()) do
      list[#list + 1] = seat
    end
  end

  entry.time, entry.list = CurTime(), list
  return list
end

-- ---------------------------------------------------------------------------
-- Seeds
-- ---------------------------------------------------------------------------
function Spots.Seeds(place, players)
  local radius, block = cvar_radius:GetFloat(), cvar_block:GetFloat()
  local seeds = {}
  if place == 'door' or place == 'chair' then
    for _, item in ipairs(Shuffle(Refresh(place == 'door' and 'doors' or 'chairs'))) do
      if (item.isSeat or IsValid(item)) and InRing(item:GetPos(), players, block, radius) then
        seeds[#seeds + 1] = item
        if #seeds >= MAX_SEEDS then break end
      end
    end
    return seeds
  end

  local ply = players[math.random(#players)]
  local points = bgNPC.Points.GetInRadius(ply:GetPos(), radius, 'walk')
  for _, point in ipairs(Shuffle(points)) do
    local pos = point:GetPos()
    if InRing(pos, players, block, radius) then
      seeds[#seeds + 1] = pos
      if #seeds >= MAX_SEEDS then break end
    end
  end
  return seeds
end

-- ---------------------------------------------------------------------------
-- Finders
-- ---------------------------------------------------------------------------
local Finders = {}
function Finders.floor(pos, scene)
  local floor = Floor(pos)
  if not floor or not Spots.HasRoom(floor) or bgNPC.Util.IsVectorInWater(floor) then return end
  if scene and scene.indoors and not Spots.InRoom(floor) then return end
  return {
    pos = floor,
    ang = Angle(0, Spots.preview and 0 or math.random(0, 359), 0)
  }
end

-- A wide, flat lip with a knee-height drop, support behind the hips and clear space for hanging legs.
local function LedgeAt(top)
  for _, dir in ipairs(Shuffle(WALL_DIRECTIONS)) do
    for distance = 8, 64, 8 do
      local edge = top + dir * distance
      local lower = Floor(edge + dir * 8)
      local support = Floor(edge - dir * 12)
      if lower and support and math.abs(support.z - top.z) <= 2 and top.z - lower.z >= 24 and top.z - lower.z <= 56 then
        local side, wide = Vector(-dir.y, dir.x, 0), true
        for _, shift in ipairs({-16, 16}) do
          local back = Floor(edge - dir * 12 + side * shift)
          local rear = Floor(edge - dir * 28 + side * shift)
          local front = Floor(edge + dir * 8 + side * shift)
          if not back or not rear or not front or math.abs(back.z - top.z) > 2 or math.abs(rear.z - top.z) > 2 or math.abs(front.z - lower.z) > 4 then
            wide = false
            break
          end
        end

        local hip = edge - dir * 12
        -- The pelvis itself must be supported, not just the points behind the edge.
        for _, shift in ipairs({-10, 0, 10}) do
          local from = hip + side * shift + Vector(0, 0, 3)
          local under = util.TraceLine({
            start = from,
            endpos = from - Vector(0, 0, 6),
            mask = MASK_SOLID_BRUSHONLY
          })

          if not under.Hit or under.StartSolid or under.HitNormal.z < 0.95 or math.abs(under.HitPos.z - top.z) > 2 then
            wide = false
            break
          end
        end

        local room = util.TraceHull({
          start = hip + Vector(0, 0, 3),
          endpos = hip + Vector(0, 0, 3),
          mins = Vector(-16, -16, 0),
          maxs = Vector(16, 16, 70),
          mask = MASK_SOLID_BRUSHONLY
        })

        if wide and not room.Hit and not room.StartSolid then
          return {
            pos = hip,
            ang = dir:Angle(),
            ledge = true
          }
        end
      end
    end
  end
end

function Finders.ledge(pos)
  local floor = Floor(pos)
  if not floor or bgNPC.Util.IsVectorInWater(floor) then return end
  local spot = LedgeAt(floor)
  if spot then return spot end
  -- Navigation normally runs beside a sill, not on top of it.
  for _, dir in ipairs(Shuffle(WALL_DIRECTIONS)) do
    local top = Floor(floor + dir * 48 + Vector(0, 0, 32))
    if top and top.z - floor.z >= 24 and top.z - floor.z <= 56 then
      spot = LedgeAt(top)
      if spot then return spot end
    end
  end
end

function Finders.sky(pos)
  local spot = Finders.floor(pos)
  if not spot then return end
  local tr = util.TraceLine({
    start = spot.pos + Vector(0, 0, 72),
    endpos = spot.pos + Vector(0, 0, 16000),
    mask = MASK_SOLID_BRUSHONLY
  })

  if not tr.HitSky then return end
  return spot
end

-- The wall must be a flat, full height brush wall at least 90 units wide: a pillar or a fence does not count.
function Finders.wall(pos, scene)
  local floor = Floor(pos)
  if not floor or bgNPC.Util.IsVectorInWater(floor) then return end
  local gap = scene.gap or 22
  local from = floor + Vector(0, 0, 36)
  for _, dir in ipairs(Shuffle(WALL_DIRECTIONS)) do
    local tr = util.TraceLine({
      start = from,
      endpos = from + dir * 80,
      mask = MASK_SOLID_BRUSHONLY
    })

    if tr.Hit and tr.HitWorld and math.abs(tr.HitNormal.z) < 0.1 then
      local normal, side = tr.HitNormal, tr.HitNormal:Cross(Vector(0, 0, 1))
      local flat = true
      -- the same trace shifted along the wall and up/down must hit the same plane
      for _, offset in ipairs({side * 45, side * -45, Vector(0, 0, 30), Vector(0, 0, -24)}) do
        local start = from + offset
        local check = util.TraceLine({
          start = start,
          endpos = start + dir * 80,
          mask = MASK_SOLID_BRUSHONLY
        })

        if not check.Hit or math.abs(check.Fraction - tr.Fraction) * 80 > 4 or check.HitNormal:Dot(normal) < 0.98 then
          flat = false
          break
        end
      end

      if flat then
        local stand = Floor(tr.HitPos + normal * gap)
        -- a leaning body touches the wall by design: the room is checked a body width away from it
        local room = Floor(tr.HitPos + normal * math.max(gap, 18))
        if stand and room and Spots.HasRoom(room) then
          return {
            pos = stand,
            ang = normal:Angle()
          }
        end
      end
    end
  end
end

-- The thin axis of the door model is its normal; the actor stands on the side with a floor and a clear view of the door.
function Finders.door(door, scene)
  if not bgNPC.Util.IsDoor(door) then return end
  local state = door:GetInternalVariable('m_eDoorState') or door:GetInternalVariable('m_toggle_state')
  local closed = door:GetClass() == 'prop_door_rotating' and 0 or 1
  if state ~= closed then return end
  local size = door:OBBMaxs() - door:OBBMins()
  local normal = size.x < size.y and door:GetForward() or door:GetRight()
  local center = door:LocalToWorld(door:OBBCenter())
  local thickness = math.min(size.x, size.y)
  local gap = thickness / 2 + (scene.gap or 40)
  for _, side in ipairs(Shuffle({1, -1})) do
    local stand = Floor(Vector(center.x, center.y, center.z - size.z / 2) + normal * side * gap)
    if stand and Spots.HasRoom(stand) then
      local look = util.TraceLine({
        start = stand + Vector(0, 0, 50),
        endpos = center,
        mask = MASK_SOLID_BRUSHONLY,
        filter = door
      })

      if not look.Hit then
        return {
          pos = stand,
          ang = Angle(0, (-normal * side):Angle().y, 0),
          door = door
        }
      end
    end
  end
end

-- Free floor next to the chair: the spawner refuses a body that overlaps a prop, so the actor appears here and Start
-- moves it onto the chair.
local function Stage(pos)
  for _, dir in ipairs(Shuffle(WALL_DIRECTIONS)) do
    local floor = Floor(pos + dir * 60)
    if floor and Spots.HasRoom(floor) then return floor end
  end
end

-- A chair of the config (like the sit_to_chair state) or a custom seat. The pose is taken once the actor exists
-- (the offset functions of the config get the NPC), here the chair is only checked.
function Finders.chair(item)
  if item.isSeat then
    if IsValid(item:GetSitting()) or (item.sitDelay or 0) > CurTime() then return end
    local stage = Floor(item:GetStartSittingPos())
    return stage and {
      pos = item:GetPos(),
      ang = item:GetAngles(),
      seat = item,
      stage = stage
    }
  end

  if not IsValid(item) or item.occupied or (item.sitDelay or 0) > CurTime() then return end
  local ang = item:GetAngles()
  if math.abs(ang.x) > 10 or math.abs(ang.z) > 10 then return end
  local data = ChairModels()[item:GetModel():lower()]
  local stage = data and Stage(item:GetPos())
  if not stage then return end
  return {
    pos = item:GetPos(),
    ang = Angle(0, ang.y, 0),
    chair = item,
    chair_data = data,
    stage = stage
  }
end

-- @return table|nil spot
function Spots.Find(place, seed, scene)
  local finder = Finders[place]
  return finder and finder(seed, scene)
end
