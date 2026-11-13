-- Copyright © 2018-2030 Decent Vehicle
-- written by ∩(≡＾ω＾≡)∩ (https://steamcommunity.com/id/greatzenkakuman/)
-- and DangerKiddy(DK) (https://steamcommunity.com/profiles/76561198132964487/).
-- Modification - Shark_vil
local Class = {}
local uid = 0
function Class:Make(name, pos, ang)
  name = name or 'FakePlayer' .. uid
  pos = pos or Vector(0, 0, 0)
  ang = ang or Angle(0, 0, 0)
  uid = uid + 1
  local ent = ents.Create('bgn_fakeplayer')
  ent.PrintName = name
  ent:SetPos(pos)
  ent:SetAngles(ang)
  return ent
end

function Class:Spawn(name, pos, ang)
  local ent = self:Make(name, pos, ang)
  ent:Spawn()
  return ent
end

slib.SetComponent('FakePlayer', Class)
