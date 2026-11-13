-- Isolated geometry/coordinator tests: no live entities, timers or navigation are changed.
local function World()
  local env = setmetatable({}, {
    __index = _G
  })

  env.bgNPC = {
    Doors = {
      held = {}
    },
    Actors = {
      GetAll = function() return {} end
    },
    Util = {}
  }

  env.hook = {
    Add = function() end
  }

  env.timer = {
    Create = function() end,
    Simple = function() end
  }

  env.IsValid = function(value) return istable(value) and value.valid == true end
  env.CurTime = function() return 100 end
  env.util = {
    TraceLine = function()
      return {
        HitWorld = true
      }
    end
  }

  env.navmesh = {
    GetNearestNavArea = function() return env.seed end,
    IsLoaded = function() return true end
  }

  function env.Load(path)
    local chunk = assert(CompileFile('background_npcs_core/' .. path))
    setfenv(chunk, env)()
  end

  function env.Area(id, pos)
    local area = {
      valid = true,
      id = id,
      pos = pos,
      adjacent = {},
      incoming = {}
    }

    function area:GetID()
      return self.id
    end

    function area:GetCenter()
      return self.pos
    end

    function area:GetClosestPointOnArea()
      return self.pos
    end

    function area:GetAdjacentAreas()
      return table.Copy(self.adjacent)
    end

    function area:GetIncomingConnections()
      return table.Copy(self.incoming)
    end

    function area:GetLadders()
      return {}
    end
    return area
  end

  env.Load('systems/siege/sv_portals.lua')
  return env
end

bgNPC.Test.Add('siege.one_exit_pocket', function(check)
  local w = World()
  local portal = {
    center = Vector(0, 0, 48),
    normal = Vector(1, 0, 0),
    right = Vector(0, 1, 0),
    floor = 0,
    width = 96
  }

  local inside, entrance, outside = w.Area(1, Vector(-160, 0, 0)), w.Area(2, Vector(-32, 0, 0)), w.Area(3, Vector(80, 0, 0))
  inside.adjacent, entrance.adjacent, outside.adjacent = {entrance}, {inside, outside}, {entrance}
  w.seed = inside
  local pocket = w.bgNPC.Siege.Pocket(portal, inside.pos)
  check(pocket and pocket[1] and pocket[2] and not pocket[3], 'the doorway separates a bounded room')
  check(w.bgNPC.Siege.Crosses(portal, Vector(-32, 40, 0), Vector(32, 40, 0)), 'both leaves share one physical cut')
  check(not w.bgNPC.Siege.Crosses(portal, Vector(-32, 200, 0), Vector(32, 200, 0)), 'a second opening is not part of that cut')
  local alternate = w.Area(4, Vector(-80, 200, 0))
  inside.adjacent[#inside.adjacent + 1] = alternate
  alternate.adjacent = {outside}
  check(w.bgNPC.Siege.Pocket(portal, inside.pos) == nil, 'a second route to the outside rejects the room')
  inside.adjacent = {entrance}
  inside.incoming = {alternate}
  check(w.bgNPC.Siege.Pocket(portal, inside.pos) == nil, 'one-way incoming connections cannot hide an alternative exit')
  inside.incoming = {}
  w.util.TraceLine = function()
    return {
      HitWorld = true,
      HitSky = true
    }
  end

  check(w.bgNPC.Siege.Pocket(portal, inside.pos) == nil, 'outdoor space is rejected')
end)

bgNPC.Test.Add('siege.animation_roles_and_shared_use', function(check)
  local w = World()
  w.Load('systems/siege/sv_siege.lua')
  local available = {
    deploy = true,
    grenThrow = true
  }

  local actor = {
    class = 'npc_metropolice',
    mechanics = {
      animator_controller = true
    }
  }

  function actor:IsValidSequence(name)
    return available[name] == true
  end

  function actor:GetNPC()
    return {
      LookupSequence = function() return 1 end,
      SequenceDuration = function() return 1 end
    }
  end

  check(w.bgNPC.Siege.Equipment(actor) == 'manhack', 'metropolice deploy manhacks')
  actor.class = 'npc_combine_s'
  check(w.bgNPC.Siege.Equipment(actor) == 'grenade', 'combine soldiers throw grenades')
  available.grenThrow = nil
  check(w.bgNPC.Siege.Equipment(actor) == nil, 'a replacement model without its throw animation cannot use the tactic')
  actor.class = 'npc_citizen'
  check(w.bgNPC.Siege.Equipment(actor) == nil, 'citizens do not receive special equipment')
  available.kickdoorbaton, available.buttonfront = true, true
  local entry = {}
  w.bgNPC.Util.Chance = function(chance)
    check(chance == 35, 'kick probability is 35 percent')
    return true
  end

  check(w.bgNPC.Siege.DoorAction(actor, entry) == 'kickdoorbaton' and entry.kick, 'successful chance chooses a supported kick')
  w.bgNPC.Util.Chance = function() return false end
  check(w.bgNPC.Siege.DoorAction(actor, entry) == 'buttonfront' and not entry.kick, 'otherwise the door is opened normally')
  available.kickdoorbaton = nil
  check(w.bgNPC.Siege.DoorAction(actor, entry) == 'buttonfront', 'missing kick animation falls back to opening')
  available.buttonfront = nil
  check(w.bgNPC.Siege.DoorAction(actor, entry) == nil, 'no door animation means no door action')
  check(w.bgNPC.Siege.Payload(actor, {
    used = true
  }) == false, 'the shared reservation rejects a second deployment before spawning anything')
end)

bgNPC.Test.Add('siege.reservation_and_wait', function(check)
  local w = World()
  local update
  w.timer.Create = function(_, _, _, fn) update = fn end
  w.Load('systems/siege/sv_siege.lua')
  local portal = {
    key = 'test',
    center = Vector(0, 0, 48),
    normal = Vector(1, 0, 0),
    right = Vector(0, 1, 0),
    floor = 0,
    width = 48,
    doors = {},
    pocket = {
      [1] = true
    }
  }

  local inside, outside = w.Area(1, Vector(-128, 0, 0)), w.Area(2, Vector(128, 69, 0))
  function outside:GetClosestPointOnArea(pos)
    return Vector(pos.x, pos.y, 0)
  end

  w.navmesh.GetNearestNavArea = function(pos) return pos.x < 0 and inside or outside end
  w.bgNPC.Doors.Floor = function(_, pos)
    if pos.y == 0 then -- narrow corridor: no side positions
      return pos
    end
  end

  w.bgNPC.Siege.Find = function() return portal end
  local enemy = {
    valid = true,
    Health = function() return 100 end,
    GetPos = function() return inside.pos end
  }

  local actor = {
    class = 'npc_metropolice',
    weapon = 'weapon_pistol',
    mechanics = {
      animator_controller = true
    },
    enemy_last_seen = {
      [enemy] = 100
    },
    enemy_last_position = {
      [enemy] = inside.pos
    }
  }

  function actor:IsValidSequence(name)
    return name == 'deploy' or name == 'Idle1'
  end

  function actor:GetNPC()
    return {
      LookupSequence = function() return 1 end,
      SequenceDuration = function() return 1 end
    }
  end

  function actor:GetPos()
    return outside.pos
  end

  function actor:GetEnemy()
    return enemy
  end

  function actor:InVehicle()
    return false
  end

  function actor:IsAlive()
    return true
  end

  function actor:HasEnemy()
    return true
  end

  function actor:HasTeam()
    return true
  end

  function actor:Voice()
  end

  function actor:IsMeleeWeapon()
    return false
  end

  function actor:HasNoEnemies()
    return false
  end

  function actor:HasState()
    return self.active == true
  end

  function actor:GetStateData()
    return {
      entry = self.entry
    }
  end

  function actor:SetState(_, _, forced)
    check(forced, 'cleanup bypasses a state delay instead of leaving participants frozen')
    self.active, self.siege = false, nil
  end

  actor.hold_fire = true
  check(w.bgNPC.Siege.CanStart(actor, enemy) == nil, 'an officer holding negotiation fire cannot initiate a siege')
  actor.hold_fire = nil
  check(w.bgNPC.Siege.CanStart(actor, enemy) == portal, 'a remembered enemy behind the doorway enables the tactic')
  local entry, member = w.bgNPC.Siege.Start(actor)
  check(entry and member and entry.near_count == 1, 'the operator reserves its entrance and position')
  check(member and member.slot.y == 0, 'a narrow corridor uses the center line instead of failing side placement')
  check(w.bgNPC.Siege.CanStart(actor, enemy) == nil, 'the reservation prevents an independent second group')
  actor.entry, actor.active = entry, true
  actor.siege = entry
  outside.pos = member.slot
  local teammates = {actor}
  local function Ally()
    local ally = setmetatable({
      pos = Vector(200, 0, 0),
      active = false,
      siege = false
    }, {
      __index = actor
    })

    function ally:GetPos()
      return self.pos
    end

    function ally:ShareEnemyMemory(source, target)
      check(source == entry.operator and target == enemy, 'joining officers receive the operator\'s observed target memory')
    end

    function ally:HasState(names)
      return istable(names) and not self.active or names == 'siege' and self.active
    end

    function ally:SetState(state, data, forced)
      if state == 'siege' then
        self.active, self.siege, self.entry, self.pos = true, data.entry, data.entry, data.member.slot
      else
        check(forced, 'withdrawal cleanup cannot be blocked by a state delay')
        self.active, self.siege = false, nil
      end
    end

    teammates[#teammates + 1] = ally
    return ally
  end

  for _ = 1, 6 do
    Ally()
  end

  local negotiating = Ally()
  negotiating.hold_fire = true
  w.bgNPC.Actors.GetAll = function() return teammates end
  update()
  check(not negotiating.siege and not entry.members[negotiating], 'a negotiating officer cannot join or lose its separate capability ownership')
  check(entry.phase == 'wait' and entry.wait_until == 112, 'the wait starts after positioning and lasts twelve seconds')
  local near, rear = 0, 0
  for _, slot in pairs(entry.members) do
    check(slot.slot.y == 0, 'the narrow corridor keeps all positions on its center line')
    if slot.near then
      near = near + 1
    else
      rear = rear + 1
      check(slot.slot:Distance(portal.center) >= 650, 'other groups have distant positions')
    end

    for _, other in pairs(entry.members) do
      if slot ~= other then check(slot.slot:Distance(other.slot) >= 85, 'corridor positions cannot overlap') end
    end
  end

  check(near == 5 and rear == 2, 'one group stays close and the remaining actors withdraw')
  Ally()
  w.bgNPC.Doors.Floor = function() end
  update()
  check(entry.cancelled, 'a close reinforcement with no withdrawal space cancels the siege')
  update()
  check(entry.finished and not actor.active, 'finishing releases participants')
  check(w.bgNPC.Siege.CanStart(actor, enemy) == nil, 'a shared target cooldown prevents another group from immediately deploying again')
end)

bgNPC.Test.Add('siege.grenade_clearance', function(check)
  local w = World()
  w.Load('systems/siege/sv_siege.lua')
  local known, origin = Vector(-200, 0, 0), Vector(200, 0, 0)
  w.seed = w.Area(1, known)
  local enemy = {
    valid = true
  }

  local npc = {
    GetPos = function() return origin end
  }

  local actor = {
    GetNPC = function() return npc end,
    GetPos = function() return origin end,
    HasEnemy = function(_, ent) return ent == enemy end,
    IsAlive = function() return true end
  }

  local ally = {
    GetNPC = function() return {} end,
    GetPos = function() return known end,
    IsAlive = function() return true end
  }

  local actors = {actor, ally}
  w.bgNPC.Actors.GetAll = function() return actors end
  w.player = {
    GetHumans = function() return {} end
  }

  w.GetConVar = function(name)
    return {
      GetFloat = function() return name == 'sv_gravity' and 600 or 250 end
    }
  end

  local traced, spawned = 0, 0
  w.util.TraceHull = function(trace)
    -- An aimed-at enemy at the landing point is not a wall; other solids remain in the trace.
    check(istable(trace.filter) and #trace.filter == 2 and trace.filter[1] == npc and trace.filter[2] == enemy, 'only the thrower and its enemy are filtered out of the ballistic path')
    traced = traced + 1
    return {
      Hit = false
    }
  end

  local phys = {
    valid = true,
    SetVelocity = function() end
  }

  local grenade = {
    valid = true,
    SetOwner = function() end,
    SetPos = function() end,
    SetAngles = function() end,
    Spawn = function() end,
    Activate = function() end,
    GetPhysicsObject = function() return phys end,
    Fire = function() end
  }

  w.ents = {
    Create = function(class)
      spawned = spawned + 1
      check(class == 'npc_grenade_frag', 'native grenade class')
      return grenade
    end
  }

  local entry = {
    known = known,
    enemy = enemy,
    kind = 'grenade',
    portal = {
      doors = {},
      pocket = {
        [1] = true
      },
      normal = Vector(1, 0, 0)
    }
  }

  check(w.bgNPC.Siege.Payload(actor, entry) == false and spawned == 0, 'a friendly actor in the blast area prevents the throw')
  actors = {actor}
  check(w.bgNPC.Siege.Payload(actor, entry) and spawned == 1 and traced == 16, 'a clear path to the enemy permits one physical throw')
  check(not w.bgNPC.Siege.Payload(actor, entry) and spawned == 1, 'the shared use prevents a second grenade')
end)
