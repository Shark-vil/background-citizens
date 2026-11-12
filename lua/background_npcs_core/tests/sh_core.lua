local Test = bgNPC.Test
local H = bgNPC.Actor.Helpers
local GhostCrowd = bgNPC.GhostCrowd
Test.Add('core.class', function(check)
  local A = bgNPC.Class('TestA')
  function A:Init(v)
    self.v = v
  end

  function A:Get()
    return self.v
  end

  local B = bgNPC.Class('TestB', A)
  function B:Init(v)
    A.Init(self, v * 2)
  end

  local b = B(3)
  check(b:Get() == 6, 'inherited method + super init')
  check(bgNPC.IsInstanceOf(b, A) and bgNPC.IsInstanceOf(b, B), 'IsInstanceOf chain')
  check(not bgNPC.IsInstanceOf(A(1), B), 'base is not subclass')
  check(getmetatable(A.New(1)) == A, 'A.New builds A')
end)

Test.Add('core.net.serializer', function(check)
  local Net = bgNPC.Net
  local nested = {
    1,
    'two',
    {
      x = Vector(1, 2.5, -3)
    },
    flag = true,
    [10] = false,
    color = Color(1, 2, 3, 4)
  }

  local values, count = Net.Deserialize(Net.Serialize(nil, 42, -0.125, 'a:b;c{}', nested, Angle(1, 2, 3), nil))
  check(count == 7, 'argument count incl. nils')
  check(values[1] == nil and values[7] == nil, 'nil arguments')
  check(values[2] == 42 and values[3] == -0.125, 'numbers')
  check(values[4] == 'a:b;c{}', 'string with separators')
  check(values[5][2] == 'two' and values[5][3].x == Vector(1, 2.5, -3), 'nested table + vector')
  check(values[5].flag == true and values[5][10] == false, 'bool values and sparse keys')
  check(IsColor(values[5].color) and values[5].color.a == 4, 'color')
  check(values[6] == Angle(1, 2, 3), 'angle')
  local cyclic = {}
  cyclic.self = cyclic
  local ok = pcall(Net.Serialize, cyclic)
  check(ok, 'cyclic table does not overflow')
  local big = string.rep('x', 100000)
  check(Net.Deserialize(Net.Serialize(big))[1] == big, 'large string')
  check(Net.Deserialize(Net.Serialize(1 / 3))[1] == 1 / 3, 'float precision')
end)

Test.Add('core.table', function(check)
  local T = bgNPC.Table
  local list = {1, 2, 3}
  local shuffled = T.Shuffle(list)
  check(#shuffled == 3 and list[1] == 1 and list[3] == 3, 'shuffle returns a copy')
  check(T.InsertUnique(list, 2) == false and T.InsertUnique(list, 4) and #list == 4, 'insert unique')
  check(T.RemoveValue(list, 2) and not T.HasValue(list, 2), 'remove value')
  check(T.IsArray(list) and not T.IsArray({
    a = 1
  }) and not T.IsArray({}), 'is array')

  check(#T.Append({1}, {2, 3}, {4}) == 4, 'append')
end)

bgNPC.Test.Add('actor.gender_by_model', function(check)
  check(H.GenderByModel('models/humans/group01/female_01.mdl') == 'female', 'female before male')
  check(H.GenderByModel('models/humans/group01/male_07.mdl') == 'male', 'male; "humans" folder ignored')
  check(H.GenderByModel('models/player/woman_police.mdl') == 'female', 'woman before man')
  check(H.GenderByModel('models/ponies/men_04.mdl') == 'male', 'men')
  check(H.GenderByModel('models/police.mdl') == 'unknown', 'unknown')
end)

bgNPC.Test.Add('ghost_crowd_rules', function(check)
  local function List(points)
    return function(callback)
      for _, pos in ipairs(points) do
        callback(pos)
      end
    end
  end

  local function Never()
    return false
  end

  local from, ply_pos = Vector(0, 0, 0), Vector(-1000, 0, 0)
  check(GhostCrowd.NextPoint(from, nil, ply_pos, false, List({Vector(-300, 0, 0), Vector(-300, 100, 0)}), Never) == nil, 'never walks towards the player')
  check(GhostCrowd.NextPoint(from, nil, ply_pos, false, List({Vector(300, 0, 500), Vector(2000, 0, 0)}), Never) == nil, 'skips too high and too far points')
  check(GhostCrowd.NextPoint(from, nil, ply_pos, false, List({Vector(300, 0, 0)}), function() return true end) == nil, 'skips blocked points')
  local pos = GhostCrowd.NextPoint(from, nil, ply_pos, true, List({Vector(300, 0, 0)}), Never)
  check(pos == nil or pos == Vector(300, 0, 0), 'runs away from the player') -- nil: a wall in the way on this map
  local seg = {
    from = Vector(0, 0, 0),
    to = Vector(100, 0, 0),
    t0 = 10,
    speed = 50
  }

  check(GhostCrowd.SegmentPos(seg, 11) == Vector(50, 0, 0), 'segment: halfway after a second')
  check(GhostCrowd.SegmentPos(seg, 99) == seg.to, 'segment: stops at the end')
  check(GhostCrowd.SegmentPos(seg, 0) == seg.from, 'segment: not before the start')
  seg.speed = 0
  check(GhostCrowd.SegmentPos(seg, 11) == seg.from, 'segment: standing still')
end)
