-- Isolated copy of systems/sv_medics.lua: stub actors, no live calls, timers or receivers are changed.
local function World()
  local w = setmetatable({}, {
    __index = _G
  })

  local hooks, actors = {}, {}
  w.IsValid = function(ent) return istable(ent) and ent.valid == true end
  w.GetConVar = function()
    return {
      GetInt = function() return 0 end
    }
  end

  w.hook = {
    Add = function(event, id, fn) hooks[event .. ':' .. id] = fn end
  }

  w.timer = {
    Create = function() end
  }

  w.Actor = function(teams)
    local actor = {
      teams = teams,
      enemies = {},
      fighting = false,
      npc = {
        valid = true
      }
    }

    function actor.npc:GetPos()
      return Vector()
    end

    function actor.npc:GetModel()
      return 'models/test.mdl'
    end

    function actor.npc:GetSkin()
      return 0
    end

    function actor:GetNPC()
      return self.npc
    end

    function actor:GetType()
      return 'test'
    end

    function actor:InVehicle()
      return false
    end

    function actor:IsAlive()
      return true
    end

    function actor:HasTeam(value)
      if isstring(value) then return self.teams[value] == true end
      for team in pairs(self.teams) do
        if value.teams[team] then return true end
      end
      return false
    end

    function actor:HasEnemy(ent)
      return self.enemies[ent] == true
    end

    actors[#actors + 1] = actor
    return actor
  end

  w.bgNPC = {
    Net = {
      Receive = function() end
    },
    Config = {
      IsTypeActive = function() return true end
    },
    Actors = {
      Get = function() end,
      GetAll = function() return actors end,
      GetByTeam = function(team)
        local list = {}
        for _, actor in ipairs(actors) do
          if actor:HasTeam(team) then list[#list + 1] = actor end
        end
        return list
      end
    },
    Combat = {
      IsFighting = function(ent)
        for _, actor in ipairs(actors) do
          if actor.npc == ent then return actor.fighting end
        end
        return false
      end
    },
    Vision = {
      -- every death is seen by everyone
      ActorsThatSee = function() return nil, actors end
    }
  }

  setfenv(assert(CompileFile('background_npcs_core/systems/sv_medics.lua')), w)()
  -- @return boolean a call was created for the victim
  w.Kill = function(victim)
    table.Empty(w.bgNPC.Medics.calls)
    hooks['BGN_OnKilledActor:BGN_Medics_Call'](victim, NULL)
    local calls = w.bgNPC.Medics.calls
    return calls[#calls] ~= nil and calls[#calls].npc == victim.npc
  end
  return w
end

bgNPC.Test.Add('medics.only_innocent', function(check)
  local w = World()
  local citizen = w.Actor({
    residents = true
  })

  local officer = w.Actor({
    residents = true,
    police = true
  })

  officer.fighting = true
  w.Actor({
    residents = true
  })

  check(w.Kill(citizen), 'a resident is saved')
  w = World()
  local resident = w.Actor({
    residents = true
  })

  local bandit, mate = w.Actor({
    gang_a = true
  }), w.Actor({
    gang_a = true
  })

  check(w.Kill(bandit), 'a bandit at peace with the residents is saved')
  resident.enemies[bandit.npc] = true
  check(not w.Kill(bandit), 'an enemy of a resident is not')
  resident.enemies[bandit.npc] = nil
  bandit.enemies[resident.npc] = true
  check(not w.Kill(bandit), 'nor one who took a resident for an enemy')
  bandit.enemies[resident.npc] = nil
  mate.enemies[resident.npc] = true
  check(w.Kill(bandit), 'a teammate hostile to the residents but not fighting does not count')
  mate.fighting = true
  check(not w.Kill(bandit), 'nor one whose teammate is fighting the residents')
end)
