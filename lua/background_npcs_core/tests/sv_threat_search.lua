-- Isolated hooks and stub entities: never touches live actors, states or cvars.
local function World()
  local w = setmetatable({
    enabled = true,
    blocked = false -- every trace hits a wall
  }, {
    __index = _G
  })

  local hooks, states, actors = {}, {}, {}
  w.states = states
  w.IsValid = function(ent) return istable(ent) and ent.valid == true end
  w.GetConVar = function(name)
    return {
      GetBool = function() return w.enabled end,
      GetString = function() return name == 'bgn_arrest_safe_weapons' and 'weapon_fists,weapon_physgun' or '' end
    }
  end

  w.hook = {
    Add = function(event, id, fn)
      hooks[event] = hooks[event] or {}
      hooks[event][id] = fn
    end,
    Run = function(event, ...)
      for _, fn in pairs(hooks[event] or {}) do
        fn(...)
      end
    end
  }

  w.timer = {
    Simple = function(_, fn) fn() end
  }

  w.util = {
    TraceLine = function()
      return {
        Hit = w.blocked
      }
    end
  }

  local function Ent(pos, opts)
    opts = opts or {}
    local ent = {
      valid = true,
      pos = pos,
      hp = 100,
      player = opts.player,
      class = opts.weapon
    }

    function ent:GetPos()
      return self.pos
    end

    function ent:WorldSpaceCenter()
      return self.pos + Vector(0, 0, 36)
    end

    function ent:EyePos()
      return self.pos + Vector(0, 0, 64)
    end

    function ent:GetForward()
      return Vector(1, 0, 0)
    end

    function ent:Health()
      return self.hp
    end

    function ent:IsPlayer()
      return self.player == true
    end

    function ent:InVehicle()
      return false
    end

    if opts.weapon ~= false then
      function ent:GetActiveWeapon()
        return {
          valid = self.class ~= nil,
          GetClass = function() return self.class end
        }
      end
    end
    return ent
  end

  w.Ent = Ent
  w.Actor = function(pos, teams)
    local actor = {
      npc = Ent(pos),
      teams = teams,
      enemies = {},
      state = 'walk',
      alive = true
    }

    actor.npc.actor = actor
    function actor:GetNPC()
      return self.npc
    end

    function actor:IsAlive()
      return self.alive
    end

    function actor:InVehicle()
      return false
    end

    function actor:HasTeam(value)
      if isstring(value) then return self.teams[value] == true end
      local other = istable(value) and (value.teams and value or value.actor)
      if not other then return false end
      for team in pairs(self.teams) do
        if other.teams[team] then return true end
      end
      return false
    end

    function actor:IsCivilian()
      return self.teams.residents and not self.teams.police
    end

    function actor:EqualStateGroup(group)
      return group == 'calm' and self.state == 'walk'
    end

    function actor:HasEnemy(ent)
      return self.enemies[ent] == true
    end

    function actor:SetState(state, data)
      self.state, self.state_data = state, data
    end

    actors[#actors + 1] = actor
    return actor
  end

  w.bgNPC = {
    Actors = {
      GetAll = function() return actors end
    },
    Combat = {
      IsAttacker = function(ent) return w.IsValid(ent) end,
      IsIgnored = function() return false end,
      CanWitness = function(_, ent) return ent.seen == true end
    },
    Modes = {
      IsPeaceful = function() return false end,
      IsFriend = function() return false end
    },
    States = {
      Register = function(name, group, def) states[name] = def end
    },
    Vision = {
      HasLineOfSight = function() return not w.blocked end
    }
  }

  setfenv(assert(CompileFile('background_npcs_core/brain/fsm/states/sv_threat_search.lua')), w)()
  w.Kill = function(victim, killer)
    victim.alive = false
    w.hook.Run('BGN_OnKilledActor', victim, killer)
  end
  return w
end

bgNPC.Test.Add('threat_search.recognition_streak', function(check)
  local w = World()
  local Count = w.bgNPC.ThreatSearch.Count
  local data, a, b = {}, {}, {}
  check(Count(data, a) == nil and Count(data, a) == nil, 'two sightings are not enough')
  check(Count(data, a) == a, 'the third sighting in a row recognizes')
  data = {}
  Count(data, a)
  Count(data, a)
  Count(data, nil)
  check(Count(data, a) == nil and data.hits == 1, 'a miss starts the streak over')
  Count(data, a)
  check(Count(data, b) == nil and data.hits == 1, 'another suspect starts the streak over')
end)

bgNPC.Test.Add('threat_search.weapon_identity', function(check)
  local w = World()
  local TS = w.bgNPC.ThreatSearch
  local actor = w.Actor(Vector(0, 0, 0), {
    police = true,
    residents = true
  })

  local stranger = w.Ent(Vector(100, 0, 0), {
    weapon = 'weapon_357',
    player = true
  })

  local killer = w.Ent(Vector(100, 0, 0), {
    weapon = 'weapon_357',
    player = true
  })

  local incident = {
    killer = killer,
    weapon = TS.WeaponClass(killer)
  }

  check(incident.weapon == 'weapon_357', 'the weapon in hand is stored')
  check(TS.IsSuspect(actor, incident, stranger), 'anyone with the same weapon is a suspect')
  stranger.class = 'weapon_pistol'
  check(not TS.IsSuspect(actor, incident, stranger), 'another weapon is not')
  local ally = w.Actor(Vector(100, 0, 0), {
    residents = true
  })

  ally.npc.class = 'weapon_357'
  check(not TS.IsSuspect(actor, incident, ally.npc), 'an ally with the weapon is not')
  check(TS.WeaponClass(w.Ent(Vector(), {
    weapon = 'weapon_fists'
  })) == nil, 'a safe weapon counts as none')

  local unarmed = w.Ent(Vector(), {
    weapon = false
  })

  incident = {
    killer = unarmed,
    weapon = TS.WeaponClass(unarmed)
  }

  check(incident.weapon == nil and TS.IsSuspect(actor, incident, unarmed), 'without GetActiveWeapon the killer is recognized in person')
  check(not TS.IsSuspect(actor, incident, w.Ent(Vector(), {
    weapon = false
  })), 'and nobody else')
end)

bgNPC.Test.Add('threat_search.witnesses', function(check)
  local w = World()
  local victim = w.Actor(Vector(500, 0, 0), {
    residents = true
  })

  local resident = w.Actor(Vector(0, 0, 0), {
    residents = true
  })

  local officer = w.Actor(Vector(0, 50, 0), {
    residents = true,
    police = true
  })

  local medic = w.Actor(Vector(0, -50, 0), {
    residents = true,
    medics = true
  })

  local behind = w.Actor(Vector(1000, 0, 0), {
    residents = true -- looks away from the victim
  })

  local far = w.Actor(Vector(-1500, 0, 0), {
    residents = true
  })

  local killer = w.Ent(Vector(600, 0, 0), {
    weapon = 'weapon_357',
    player = true
  })

  w.Kill(victim, killer)
  check(resident.state == 'panic' and resident.state_data.incident.weapon == 'weapon_357', 'a resident panics')
  check(officer.state == 'search_threat', 'an officer searches')
  check(officer.state_data.incident.pos == killer:GetPos(), 'the search goes where the killer stood')
  check(medic.state == 'walk', 'a medic keeps on')
  check(behind.state == 'panic', 'no view cone: a witness looking away panics too')
  check(far.state == 'walk', 'out of range sees nothing')
  local w2 = World()
  victim = w2.Actor(Vector(500, 0, 0), {
    residents = true
  })

  resident = w2.Actor(Vector(0, 0, 0), {
    residents = true
  })

  killer = w2.Ent(Vector(600, 0, 0), {
    weapon = 'weapon_357'
  })

  killer.seen = true
  w2.Kill(victim, killer)
  check(resident.state == 'walk', 'one who sees the killer is left to the ordinary reactions')
  local w3 = World()
  w3.enabled = false
  victim = w3.Actor(Vector(500, 0, 0), {
    residents = true
  })

  resident = w3.Actor(Vector(0, 0, 0), {
    residents = true
  })

  w3.Kill(victim, w3.Ent(Vector(600, 0, 0)))
  check(resident.state == 'walk', 'off by default: nothing happens')
  local w4 = World()
  w4.blocked = true
  victim = w4.Actor(Vector(500, 0, 0), {
    residents = true
  })

  resident = w4.Actor(Vector(0, 0, 0), {
    residents = true
  })

  w4.Kill(victim, w4.Ent(Vector(600, 0, 0)))
  check(resident.state == 'walk', 'a death behind a wall is not seen')
end)
