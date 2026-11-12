bgNPC.Test.Add('animator.lifecycle', function(check)
  -- Isolate engine stubs so this test never creates or changes live entities.
  local env = setmetatable({
    SERVER = true,
    CLIENT = false
  }, {
    __index = _G
  })

  local now, messages, callbacks, players = 100, {}, {}, {}
  local function Entity()
    local e = {
      valid = true,
      state = 1,
      schedule = 0
    }

    function e:Remove()
      self.valid = false
    end

    function e:IsDormant()
      return false
    end

    function e:GetNoDraw()
      return false
    end

    function e:TestPVS()
      return true
    end

    function e:GetPos()
      return Vector()
    end

    function e:GetAngles()
      return Angle()
    end

    function e:GetModelScale()
      return 1
    end

    function e:LookupSequence()
      return 1, 5
    end

    function e:Health()
      return 100
    end

    function e:IsNPC()
      return true
    end

    function e:IsCurrentSchedule(s)
      return self.schedule == s
    end

    function e:GetNPCState()
      return self.state
    end

    function e:SetNPCState(s)
      self.state = s
    end

    function e:SetSchedule(s)
      self.schedule = s
    end

    function e:ClearSchedule()
      self.schedule = 0
    end

    for _, method in ipairs({'SetModel', 'SetPos', 'SetAngles', 'SetModelScale', 'SetRenderMode', 'DrawShadow', 'SetCollisionGroup', 'SetParent', 'Spawn', 'ResetSequence', 'SetCycle'}) do
      e[method] = function() end
    end
    return e
  end

  env.IsValid = function(e) return type(e) == 'table' and e.valid == true end
  env.CurTime = function() return now end
  env.player = {
    GetHumans = function() return players end
  }

  env.ents = {
    Create = Entity
  }

  env.util = {
    IsValidModel = function() return true end
  }

  env.hook = {
    Add = function(event, _, f) callbacks[event] = f end,
    Run = function() end
  }

  env.bgNPC = {
    Net = {
      Send = function(...) messages[#messages + 1] = {...} end
    },
    Actors = {
      Get = function() end
    }
  }

  setfenv(CompileFile('background_npcs_core/core/sh_animator.lua'), env)()
  local a, npc, viewer = env.bgNPC.Animator, Entity(), Entity()
  viewer.bgn_ready = true
  players[1] = viewer
  local info = a.Play('models/player/kleiner.mdl', 'Taunt_Dance', npc)
  check(info and #messages == 1, 'initial viewer receives the animation')
  callbacks.Think()
  check(npc.schedule == SCHED_NPC_FREEZE, 'Animator freezes the NPC')
  check(#messages == 1, 'same viewer gets no duplicate start')
  local late = Entity()
  late.bgn_ready = true
  players[2] = late
  now = 101
  callbacks.Think()
  check(#messages == 2 and messages[2][2] == late and messages[2][7] == 105, 'late viewer receives the original deadline')
  late.TestPVS = function() return false end
  now = 102
  callbacks.Think()
  late.TestPVS = function() return true end
  now = 103
  callbacks.Think()
  check(#messages == 3, 'returning viewer receives the active animation again')
  now = 106
  callbacks.Think()
  check(not a.IsPlaying(npc) and npc.schedule == 0 and npc.state == 1, 'natural completion releases the NPC')
  local loop = a.Play('models/player/kleiner.mdl', 'Taunt_Dance', npc, {
    loop = true
  })

  callbacks.Think()
  now = 112
  callbacks.Think()
  check(a.IsPlaying(npc) and loop.stop_time == 117, 'loop remains active after one duration')
  npc.schedule, npc.state = 99, 3
  a.Stop(npc)
  check(npc.schedule == 99 and npc.state == 3, 'stop preserves a replacement schedule')
  local states = {}
  env.bgNPC.States = {
    Register = function(name, _, state) states[name] = state end
  }

  env.bgNPC.Commands = {
    Register = function() end
  }

  setfenv(CompileFile('background_npcs_core/brain/fsm/states/sh_dance.lua'), env)()
  check(states.dance.pre_start == nil and isfunction(states.dance.start), 'dance starts after SetState resets the old animation')
  local actor = {
    GetNPC = function() return npc end,
    SetState = function(self, state) self.state = state end
  }

  local data = {}
  states.dance.start(actor, 'dance', data)
  check(a.IsPlaying(npc) and data.anim_info == a.Get(npc), 'dance start retains its animation')
  a.Stop(npc)
  npc.GetNoDraw = function() return true end
  states.dance.start(actor, 'dance', {})
  check(actor.state == 'walk', 'failed dance returns to walking')
end)
