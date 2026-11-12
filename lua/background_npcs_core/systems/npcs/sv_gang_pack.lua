-- Living gang members form packs of up to three, ordered by entity index.
-- Followers stay near their leader at its pace; combat support is independent of packs.
local GangPack = {}
bgNPC.GangPack = GangPack
local RADIUS = 1500
local FOLLOW_DELAY = 2
local SPREAD_MIN, SPREAD_MAX = 80, 180
local function Leader(actor)
  local members = {}
  for _, other in ipairs(bgNPC.Actors.GetAll()) do
    if other.data.gang == actor.data.gang and other:IsAlive() then members[#members + 1] = other end
  end

  table.sort(members, function(a, b) return a:GetNPC():EntIndex() < b:GetNPC():EntIndex() end)
  local packs = {}
  for _, member in ipairs(members) do
    local selected
    for _, pack in ipairs(packs) do
      if pack.size < 3 and member:GetPos():DistToSqr(pack.leader:GetPos()) <= RADIUS * RADIUS then
        selected = pack
        break
      end
    end

    if not selected then
      selected = {
        leader = member,
        size = 0
      }

      packs[#packs + 1] = selected
    end

    selected.size = selected.size + 1
    if member == actor then return selected.leader end
  end
  return actor
end

-- @param position Vector the destination the walk state has picked
-- @return Vector, number|nil, string|nil the destination, the delay before the next pick (nil = the usual one)
--	and the movement type to use (nil = the actor's own)
function GangPack.Destination(actor, position)
  if not actor.data.gang then return position end
  local leader = Leader(actor)
  if leader == actor then
    actor.pack_leader = nil
    return position
  end

  if actor.pack_leader ~= leader then
    local angle = math.random() * math.pi * 2
    local spread = math.random(SPREAD_MIN, SPREAD_MAX)
    actor.pack_leader = leader
    actor.pack_offset = Vector(math.cos(angle) * spread, math.sin(angle) * spread, 0)
  end
  return leader:GetPos() + actor.pack_offset, FOLLOW_DELAY, leader:GetStateData().schedule
end
