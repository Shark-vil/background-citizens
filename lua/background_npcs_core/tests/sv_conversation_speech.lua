bgNPC.Test.Add('conversations.ambient_speech', function(check)
  local actors, timers, tasks = {}, {}, {}
  local hooks, enabled, now = 0, true, 100
  local env = setmetatable({
    bgNPC = {
      Table = {
        Random = function(lines) return lines[1], 1 end
      },
      Util = {
        Chance = function() return true end
      },
      Actors = {
        GetAll = function() return actors end,
        GetByTeam = function() return actors end
      },
      Tasks = {
        Add = function(id, fn) tasks[id] = fn end
      },
      cfg = {
        replics = {
          calm = {'ambient line'}
        }
      },
    },
    GetConVar = function()
      return {
        GetBool = function() return enabled end
      }
    end,
    CurTime = function() return now end,
    IsValid = function(ent) return ent ~= nil end,
    timer = {
      Create = function(id, _, _, fn) timers[id] = fn end
    },
    hook = {
      Run = function() hooks = hooks + 1 end
    },
  }, {
    __index = _G
  })

  for _, path in ipairs({'actor/events/sv_state_randomize.lua', 'systems/npcs/sv_random_voice.lua'}) do
    setfenv(assert(CompileFile('background_npcs_core/' .. path)), env)()
  end

  local function Actor(replics)
    local actor = {
      lines = 0,
      coughs = 0
    }

    local npc = {
      EmitSound = function() actor.coughs = actor.coughs + 1 end
    }

    function actor:IsAlive()
      return true
    end

    function actor:InVehicle()
      return false
    end

    function actor:GetNPC()
      return npc
    end

    function actor:GetData()
      return {
        replics = replics
      }
    end

    function actor:HasState()
      return true
    end

    function actor:EqualStateGroup()
      return true
    end

    function actor:SayReplic()
      self.lines = self.lines + 1
    end

    actors[#actors + 1] = actor
    return actor
  end

  -- Cover both config paths, and a free actor after the conversation participants.
  local named = Actor({
    state_names = {
      dialogue = 'calm'
    }
  })

  local grouped = Actor({
    state_groups = {
      calm = 'calm'
    }
  })

  local free = Actor({
    state_groups = {
      calm = 'calm'
    }
  })

  local coughs = coroutine.create(tasks.BGN_ActorsResidentsRandomVoice)
  local function Tick()
    timers.BGN_Timer_StateRandomizeReplics()
    for _ = 1, #actors + 1 do
      local ok, err = coroutine.resume(coughs, coroutine.yield, coroutine.yield)
      assert(ok, err)
    end
  end

  for _, phase in ipairs({'gather', 'talk', 'react'}) do
    named.conversation, grouped.conversation = {
      phase = phase
    }, {
      phase = phase
    }

    now = now + 100
    Tick()
    check(named.lines == 0 and grouped.lines == 0, phase .. ': no random state lines')
    check(named.coughs == 0 and grouped.coughs == 0, phase .. ': no ambient coughs')
    check(named._delay_cough_sound == nil and grouped._delay_cough_sound == nil, 'suppressed coughs do not consume cooldown')
  end

  check(free.lines == 3 and free.coughs == 3 and hooks == 3, 'free actors still speak and emit their hooks')
  named.conversation, grouped.conversation = nil, nil
  now = now + 100
  Tick()
  check(named.lines == 1 and grouped.lines == 1, 'random lines resume after the conversation')
  check(named.coughs == 1 and grouped.coughs == 1 and hooks == 6, 'coughs and line hooks resume')
  enabled = false
  Tick()
  check(hooks == 6, 'the random-line setting still disables lines')
  check(named.coughs == 1 and grouped.coughs == 1, 'cough cooldown still applies')
end)
