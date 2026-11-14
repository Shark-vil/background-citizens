-- Isolated copies of the real modules; no live tasks, entities, timers or receivers are changed.
local function World()
  local w = setmetatable({
    SERVER = true,
    CLIENT = false,
    now = 0
  }, {
    __index = _G
  })

  w.BGN_ACTOR = {}
  w.bgNPC = {
    Class = bgNPC.Class,
    Table = bgNPC.Table,
    Actors = {},
    Config = {},
    Assert = bgNPC.Assert
  }

  w.CurTime = function() return w.now end
  w.RealTime, w.SysTime = w.CurTime, w.CurTime
  w.IsValid = function(ent) return istable(ent) and ent.valid == true end
  w.hooks, w.timers, w.receivers, w.tasks = {}, {}, {}, {}
  w.hook = {
    Add = function(event, id, fn) w.hooks[event .. ':' .. id] = fn end,
    Remove = function(event, id) w.hooks[event .. ':' .. id] = nil end,
    Run = function() end
  }

  w.cvars = {
    AddChangeCallback = function() end
  }

  w.concommand = {
    Add = function() end
  }

  w.bgNPC.Commands = {
    Register = function() end
  }

  w.timer = {
    Create = function(id, _, _, fn) w.timers[id] = fn end,
    Remove = function(id) w.timers[id] = nil end,
    Simple = function() end
  }

  w.bgNPC.Tasks = {
    Add = function(id, fn) w.tasks[id] = coroutine.create(fn) end,
    Budget = function() end
  }

  w.GetConVar = function() return nil end
  w.CreateConVar = function(_, default)
    return {
      GetFloat = function() return tonumber(default) end,
      GetString = function() return default end
    }
  end

  w.util = {
    AddNetworkString = function() end,
    Decompress = function(data, limit)
      w.decompress_limit = limit
      return data
    end
  }

  w.net = {
    Receive = function(id, fn) w.receivers[id] = fn end
  }

  w.ErrorNoHalt = function(err) error(err) end
  w.Load = function(path) setfenv(assert(CompileFile('background_npcs_core/' .. path)), w)() end
  w.Resume = function(id)
    local co = w.tasks[id]
    local ok, err = coroutine.resume(co, coroutine.yield, coroutine.yield, function() end)
    assert(ok, err)
    return coroutine.status(co)
  end
  return w
end

bgNPC.Test.Add('audit.uid_reload', function(check)
  local w = World()
  w.Load('core/sh_util.lua')
  local old = w.bgNPC.Util.NextId
  local before = old()
  w.Load('core/sh_util.lua')
  check(w.bgNPC.Util.NextId() > before and old() > before + 1, 'old and new consumers share the same counter after reload')
end)

bgNPC.Test.Add('audit.mechanics', function(check)
  local w = World()
  w.Load('core/sh_util.lua')
  w.hooks['BGN_InitActor:BGN_iNPC_IgnoreActors'] = function() end
  w.Load('actor/sh_actor.lua')
  check(not w.hooks['BGN_InitActor:BGN_iNPC_IgnoreActors'], 'reload retires the duplicate hook that forced iNPC ignore')
  local actor = setmetatable({}, w.bgNPC.Actor)
  -- Stop construction at the first entity access; flags have already been built from real config data.
  w.bgNPC.Config.GetActor = function()
    return {
      mechanics = {
        movement_controller = false,
        inpc_ignore = false,
        custom = false
      }
    }
  end

  pcall(actor.Init, actor, {}, 'test')
  check(actor.mechanics.movement_controller == false and actor.mechanics.inpc_ignore == false, 'false overrides survive defaults')
  check(actor.mechanics.states_controller == true and actor.mechanics.custom == false, 'defaults and custom flags survive')
end)

bgNPC.Test.Add('audit.scheduler_mutation', function(check)
  local w = World()
  w.Load('core/sh_tasks.lua')
  local tasks, runs = w.bgNPC.Tasks, {}
  tasks.Add('remove', function()
    tasks.Remove('remove')
    tasks.Remove('later')
    tasks.Add('new', function() runs.new = true end)
  end)

  tasks.Add('later', function() error('removed task ran') end)
  tasks.Add('survivor', function(yield)
    while true do
      runs.survivor = (runs.survivor or 0) + 1
      yield()
    end
  end)

  local tick = w.hooks['Think:BGN_Tasks']
  tick()
  check(runs.survivor == 1 and not runs.new, 'mutation neither skips nor repeats original surviving tasks')
  tick()
  check(runs.survivor == 2 and runs.new, 'new task starts on the next tick')
  tasks.Remove('survivor')
  tasks.Add('last', function() tasks.Remove('last') end)
  check(pcall(tick) and #tasks.order == 0, 'removing the last task does not invalidate iteration')
end)

bgNPC.Test.Add('audit.net_malformed', function(check)
  local w = World()
  w.Load('core/sh_net.lua')
  local net = w.bgNPC.Net
  for _, data in ipairs({'n-1;', 'ninf;', 'n1.5;_', 'n999999999;', 'x0;', 'n0;extra', 'n1;s-1:x', 'n1;s9:x', 'n1;s1.5:xy', 'n1;{'}) do
    check(not pcall(net.Deserialize, data), 'reject malformed payload ' .. data)
  end

  check(not pcall(net.Deserialize, 'n1;' .. string.rep('{s1:x', 65) .. '_' .. string.rep('}', 65)), 'reject excessive table depth')
  check(not pcall(net.Deserialize, net.Serialize({
    a = 1,
    b = 2
  }), 4), 'value budget bounds table expansion')

  local object = {}
  function object:NetSerialize()
    return self
  end

  local ok, data = pcall(net.Serialize, object)
  check(ok and net.Deserialize(data)[1] == nil, 'self-referencing custom serializer terminates')
  local values, count = net.Deserialize(net.Serialize(nil, false, '', {
    key = 'value'
  }, nil))

  check(count == 5 and values[2] == false and values[3] == '' and values[4].key == 'value', 'valid wire format and nil arguments preserved')
end)

bgNPC.Test.Add('audit.net_chunks', function(check)
  local w = World()
  w.Load('core/sh_net.lua')
  local dispatched, packet = 0, nil
  w.bgNPC.Net.Receive('test', function() dispatched = dispatched + 1 end)
  w.bgNPC.Net.Receive('other', function() dispatched = dispatched + 1 end)
  w.net.ReadString = function() return packet.name end
  w.net.ReadBool = function() return packet.compressed end
  w.net.BytesLeft = function() return #packet.data, #packet.data * 8 end
  w.net.ReadData = function() return packet.data end
  local sender = {
    valid = true
  }

  local function Receive(id, part, total, data, name, compressed, length)
    packet = {
      name = name or 'test',
      data = data,
      compressed = compressed == true
    }

    local values, index = {total, id, part, length or #data}, 0
    if total == 1 then values = {total, length or #data} end
    w.net.ReadUInt = function()
      index = index + 1
      return values[index]
    end

    w.receivers.bgn_net(0, sender)
  end

  Receive(1, 2, 2, ';')
  Receive(1, 1, 2, 'n0')
  check(dispatched == 1, 'out-of-order complete transfer dispatches once')
  Receive(2, 1, 2, 'n0')
  Receive(2, 2, 2, ';', 'other')
  check(dispatched == 1, 'message names cannot share an assembly')
  Receive(3, 0, 2, 'n0;')
  Receive(3, 1, 0, 'n0;')
  Receive(3, 1, 2, 'n0;', nil, false, 100)
  Receive(3, 1, 2, string.rep('x', 60001))
  check(dispatched == 1, 'invalid indexes, totals and lengths are dropped')
  Receive(4, 1, 1, 'n0;', nil, true)
  check(dispatched == 2 and w.decompress_limit == 32 * 1024 * 1024, 'client decompression is bounded')
  Receive(5, 1, 1, 'n257;' .. string.rep('_', 257))
  check(dispatched == 2, 'oversized argument lists cannot overflow callback unpacking')
  for id = 10, 18 do
    Receive(id, 1, 2, 'n0')
  end

  for id = 10, 18 do
    Receive(id, 2, 2, ';')
  end

  check(dispatched == 10, 'only eight incomplete client transfers are kept')
  w.now = 100
  w.timers.bgn_net_buffers_cleanup()
  for part = 1, 140 do
    w.now = 100 + math.floor((part - 1) / 80) * 2
    Receive(100, part, 140, string.rep('x', 60000))
  end

  check(dispatched == 10, 'aggregate client fragment bytes cannot exceed 8 MiB')
  w.util.Compress = function(data) return data end
  w.bgNPC.Net.Send('large', sender, string.rep('x', 60001))
  local id = w.bgNPC.Net.message_id
  local first = w.timers['bgn_net_send_' .. id]
  w.Load('core/sh_net.lua')
  w.bgNPC.Net.Send('large', sender, string.rep('x', 60001))
  check(w.bgNPC.Net.message_id > id and w.timers['bgn_net_send_' .. id] == first, 'reload cannot replace another transfer timer')
end)

bgNPC.Test.Add('audit.random_points', function(check)
  local w = World()
  w.Load('nav/sh_node_graph.lua')
  local graph = w.bgNPC.NodeGraph()
  check(graph:GetRandom(Vector(), 100) == nil, 'empty radius returns nil')
  graph:AddNode(Vector(1000, 0, 0))
  check(graph:GetRandom(nil, nil, 'walk') == nil, 'no matching link type returns nil')
  w.Load('nav/sv_nav.lua')
  w.Load('nav/providers/sv_graph_provider.lua')
  local provider = w.bgNPC.Nav.GraphProvider(graph)
  check(provider:GetRandomPoint(Vector(), 100) == nil, 'empty local query does not fall back to anywhere on the map')
  local calls = 0
  local area = {
    valid = true,
    IsUnderwater = function() return false end,
    GetSizeX = function() return 100 end,
    GetSizeY = function() return 100 end,
    GetCenter = function() return Vector(10, 20, 30) end,
    GetRandomPoint = function() return Vector(10, 20, 30) end
  }

  w.navmesh = {
    IsLoaded = function() return true end,
    GetNavAreaCount = function() return 1 end,
    GetAllNavAreas = function() return {area} end,
    Find = function() return {} end,
    GetNavAreaByID = function() calls = calls + 1 end
  }

  w.Load('nav/providers/sv_navmesh_provider.lua')
  provider = w.bgNPC.Nav.NavMeshProvider()
  provider:Load()
  check(provider:GetRandomPoint() == Vector(10, 20, 30) and #provider:GetAllPoints() == 64 and calls == 0, 'sample actual areas independently of sparse IDs')
  check(provider:GetRandomPoint(Vector(), 100) == nil, 'empty navmesh radius returns nil')
end)

bgNPC.Test.Add('audit.recurring_services', function(check)
  local w, actors, players = World(), {}, {}
  w.bgNPC.Actors.GetAll = function() return actors end
  w.bgNPC.Actors.GetByTeam = function() return actors end
  w.bgNPC.Util = {
    Chance = function() return true end,
    IsDoor = function() return true end
  }

  w.player = {
    GetAll = function() return players end
  }

  w.ents = {
    FindInSphere = function() return w.near and {{}} or {} end
  }

  w.Load('actor/events/sv_door_pass.lua')
  w.Load('systems/npcs/sv_random_voice.lua')
  w.Load('systems/sv_player_look_at_object.lua')
  local door, voice, look = 'BGN_DoorPass', 'BGN_ActorsResidentsRandomVoice', 'BGN_Timer_PlayerLookAtObject'
  for _, id in ipairs({door, voice, look}) do
    w.Resume(id)
    check(w.Resume(id) == 'suspended', 'service survives an empty world: ' .. id)
  end

  local npc = {
    valid = true,
    group = COLLISION_GROUP_NPC,
    sounds = 0
  }

  function npc:GetCollisionGroup()
    return self.group
  end

  function npc:SetCollisionGroup(group)
    self.group = group
  end

  function npc:GetPos()
    return Vector()
  end

  function npc:EmitSound()
    self.sounds = self.sounds + 1
  end

  actors[1] = {
    GetNPC = function() return npc end,
    IsAlive = function() return true end,
    EqualStateGroup = function() return true end
  }

  w.near = true
  w.Resume(door)
  check(npc.group == COLLISION_GROUP_NPC_SCRIPTED, 'later actor enters doorway collision group')
  w.Resume(door)
  w.near = false
  w.Resume(door)
  check(npc.group == COLLISION_GROUP_NPC, 'later pass restores collision group')
  w.Resume(voice)
  w.now = 100
  w.Resume(voice)
  w.Resume(voice)
  check(npc.sounds == 2, 'ambient voices continue after the first pass')
  local ply = {
    valid = true,
    Alive = function() return true end,
    EyePos = function() return Vector() end,
    EyeAngles = function() return Angle() end
  }

  players[1] = ply
  local target, seen, elapsed = {
    valid = true
  }, true, nil

  w.util.TraceLine = function()
    return {
      Hit = seen,
      Entity = target
    }
  end

  w.hook.Run = function(_, _, _, duration) elapsed = duration end
  w.Resume(look)
  w.now = 105
  w.Resume(look)
  w.Resume(look)
  check(elapsed == 5, 'continuous observation accumulates across passes')
  seen = false
  w.Resume(look)
  w.Resume(look)
  seen = true
  w.now = 110
  w.Resume(look)
  w.Resume(look)
  check(elapsed == 0, 'looking away resets continuous observation')
  local seen_objects, looked_objects, traces = 0, 0, 0
  npc.IsNPC = function() return true end
  npc.GetShootPos = function() return Vector() end
  npc.GetAngles = function() return Angle() end
  npc.GetForward = function() return Vector(1, 0, 0) end
  actors[1].IsAlive = function() return npc.valid end
  w.bgNPC.Vision = {
    NPCCanSeePos = function() return true end
  }

  w.ents.FindInSphere = function()
    return {
      {
        valid = true,
        GetPos = function() return Vector(20, 0, 0) end
      },
      {
        valid = true,
        GetPos = function() return Vector(40, 0, 0) end
      }
    }
  end

  w.util.TraceLine = function()
    traces = traces + 1
    return {
      Hit = true
    }
  end

  w.hook.Run = function(event)
    if event == 'BGN_ActorVisibleAtObject' then seen_objects = seen_objects + 1 end
    if event == 'BGN_ActorLookAtObject' then looked_objects = looked_objects + 1 end
  end

  w.Load('systems/sv_npc_look_at_object.lua')
  w.Resume('BGN_Timer_ActorLookAtObject')
  check(seen_objects == 2 and looked_objects == 2 and traces == 1, 'one actor scan completes without per-object yields and shares one forward trace')
  w.hook.Run = function(event) if event == 'BGN_ActorVisibleAtObject' then npc.valid = false end end
  w.Resume('BGN_Timer_ActorLookAtObject')
  w.Resume('BGN_Timer_ActorLookAtObject')
  check(not npc.valid and traces == 1, 'a callback removing the body stops the scan before further engine calls')
end)

bgNPC.Test.Add('audit.regeneration', function(check)
  local w = World()
  local npc = {
    valid = true,
    hp = 5,
    GetMaxHealth = function() return 100 end,
    IsEFlagSet = function() return false end
  }

  function npc:Health()
    return self.hp
  end

  function npc:SetHealth(hp)
    self.hp = hp
  end

  local data = {
    regeneration = true,
    regeneration_time = 7,
    regeneration_max_health = 6
  }

  local actor = {
    GetNPC = function() return npc end,
    GetData = function() return data end,
    IsAlive = function() return true end
  }

  w.bgNPC.Actors.GetAll = function() return {actor} end
  w.Load('systems/npcs/sv_regeneration.lua')
  w.now = 100
  w.Resume('BGN_ActorsRegeneration')
  check(npc.hp == 6 and actor._last_regeneration_update_time == 107, 'configured interval and health ceiling are used')
  w.now = 105
  w.Resume('BGN_ActorsRegeneration')
  w.Resume('BGN_ActorsRegeneration')
  check(actor._last_regeneration_update_time == 107, 'regeneration waits for its configured interval')
  npc.hp, w.now = 10, 110
  w.Resume('BGN_ActorsRegeneration')
  w.Resume('BGN_ActorsRegeneration')
  check(npc.hp == 10, 'regeneration never reduces health above its configured ceiling')
end)

bgNPC.Test.Add('audit.goap_multi_effects', function(check)
  local w = World()
  w.Load('nav/sh_astar.lua')
  w.Load('brain/goap/sv_goap.lua')
  local g = w.bgNPC.GOAP
  local goal = g.Goal('same_name', {
    want = {
      a = true,
      b = true,
      c = true
    }
  })

  local direct = g.Action('direct', {
    effects = {
      a = true,
      b = true,
      c = true
    },
    cost = 2.5
  })

  local prepare = g.Action('prepare', {
    effects = {
      ready = true
    }
  })

  local finish = g.Action('finish', {
    pre = {
      ready = true
    },
    effects = {
      a = true,
      b = true,
      c = true
    }
  })

  local plan = g.Plan(0, goal, {direct, prepare, finish})
  check(plan and #plan == 2 and plan[1] == prepare and plan[2] == finish, 'heuristic does not overestimate multi-effect actions')
  local impossible = g.Goal('same_name', {
    want = {
      absent = true
    }
  })

  check(g.Plan(0, impossible, {direct, prepare, finish}) == nil, 'goal conditions distinguish cache entries with equal names')
  w.Load('brain/goap/sv_goap_actions.lua')
  local replace_goal = g.Goal('replace', {
    want = {
      a = true
    }
  })

  g.RegisterAction('replace', {
    effects = {
      a = true
    }
  })

  local old_action = g.actions.replace
  g.Plan(0, replace_goal, {old_action})
  g.RegisterAction('replace', {
    effects = {
      a = true
    },
    cost = 2
  })

  check(g.Plan(0, replace_goal, {g.actions.replace})[1] == g.actions.replace, 'registered action replacement invalidates cached objects')
end)

bgNPC.Test.Add('audit.sync_reload', function(check)
  local w, actors, sent = World(), {}, {}
  w.Load('core/sh_util.lua')
  local actor = {
    uid = 100,
    sync_players_hash = {},
    enemies = {},
    targets = {}
  }

  local npc = {
    valid = true,
    GetNoDraw = function() return false end
  }

  function actor:GetNPC()
    return npc
  end

  function actor:IsAlive()
    return true
  end

  function actor:InVehicle()
    return false
  end

  function actor:HasState()
    return false
  end

  function actor:GetState()
    return 'walk'
  end

  function actor:GetType()
    return 'citizen'
  end

  function actor:GetName()
    return 'Test'
  end

  function actor:GetGender()
    return 'male'
  end

  actors[1] = actor
  local ply = {
    valid = true,
    bgn_ready = true,
    TestPVS = function() return true end
  }

  w.player = {
    GetHumans = function() return {ply} end
  }

  w.bgNPC.Actors.GetAll = function() return actors end
  w.bgNPC.States = {
    GetGroup = function() return 'calm' end
  }

  w.bgNPC.Net = {
    Serialize = function() return '' end,
    Send = function(_, _, _, _, _, seq) sent[#sent + 1] = seq end
  }

  w.util.CRC = function() return '0' end
  w.Load('actor/sync/sv_sync.lua')
  w.Resume('BGN_SynchronizationService')
  actor.sync_players_hash = {}
  w.Load('core/sh_util.lua')
  w.Load('actor/sync/sv_sync.lua')
  w.Resume('BGN_SynchronizationService')
  check(#sent == 2 and sent[2] > sent[1], 'new sync sequence cannot be older than a pre-reload snapshot')
end)

bgNPC.Test.Add('audit.client_seat_receiver', function(check)
  local w = World()
  w.SERVER, w.CLIENT = false, true
  w.bgNPC.Net = {
    Receive = function(name, fn) w.receivers[name] = fn end
  }

  local tool = {
    SeatPoints = {}
  }

  w.bgNPC.Util = {
    GetActivePlayerTool = function() return tool end
  }

  w.Load('systems/seats/sh_seat_saver.lua')
  check(pcall(w.receivers.cl_bgn_tool_seat_load, nil, {}), 'server-to-client callback needs no sender entity')
end)

bgNPC.Test.Add('audit.spawnmenu_io', function(check)
  local w, reads, invalidations, pending = World(), 0, 0, nil
  w.bgNPC.cfg = {
    actors = {
      citizen = {
        class = 'npc_citizen'
      }
    }
  }

  w.bgNPC.SpawnMenu = {
    Creator = {
      NPC = {},
      Default = {}
    }
  }

  w.bgNPC.Config.ClearCache = function() invalidations = invalidations + 1 end
  w.bgNPC.Net = {
    Receive = function(name, fn) w.receivers[name] = fn end
  }

  w.file = {
    Exists = function() return true end,
    Read = function()
      reads = reads + 1
      return ''
    end
  }

  w.util.JSONToTable = function()
    return {
      custom = {'citizen'}
    }
  end

  w.list = {
    Get = function()
      return {
        custom = {
          Class = 'custom_citizen',
          Model = 'test.mdl'
        }
      }
    end
  }

  w.timer.Simple = function(_, fn) pending = fn end
  w.Load('ui/spawnmenu/sv_spawnmenu.lua')
  check(not w.hooks['OnEntityCreated:BGN_InitServerSPawnmenu'], 'entity creation performs no config disk I/O')
  pending()
  check(reads == 1 and invalidations == 1, 'reload loads config and invalidates resolved actors')
  check(w.bgNPC.Table.HasValue(w.bgNPC.cfg.actors.citizen.class, 'custom_citizen'), 'custom NPC class mapping preserved')
  local ply = {}
  w.bgNPC.SpawnMenu.Creator.Default[ply] = 'citizen'
  w.hooks['PlayerDisconnected:BGN_SpawnmenuDefaults'](ply)
  check(w.bgNPC.SpawnMenu.Creator.Default[ply] == nil, 'player default drops its disconnected owner')
end)

bgNPC.Test.Add('audit.client_retirement', function(check)
  local original_factory = BGN_ACTOR and BGN_ACTOR.BaseClass
  local w = World()
  w.SERVER, w.CLIENT = false, true
  local pending
  w.timer.Simple = function(_, fn) pending = fn end
  w.bgNPC.Util = {
    NextId = function() return 1 end,
    Chance = function() return false end
  }

  w.bgNPC.Net = {
    Receive = function(name, fn) w.receivers[name] = fn end
  }

  w.bgNPC.cfg = {
    npc_names = {
      male = {'Test'},
      female = {'Test'}
    }
  }

  w.bgNPC.Config.GetActor = function() return {} end
  w.Load('actor/sh_actor.lua')
  w.bgNPC.Actor.InVehicle = function() return false end
  w.Load('api/sh_actors.lua')
  local npc = {
    valid = true,
    EntIndex = function() return 1 end,
    GetClass = function() return 'npc_citizen' end,
    GetSkin = function() return 0 end,
    GetModel = function() return 'models/male_01.mdl' end,
    GetCollisionGroup = function() return 0 end,
    GetModelScale = function() return 1 end,
    GetBodyGroups = function() return {} end
  }

  local actor = w.bgNPC.Actor.New(npc, 'citizen')
  w.bgNPC.Actors.Register(actor)
  w.receivers.bgm_update_death_actors_on_client(nil, npc, actor.uid)
  pending()
  check(actor.is_removed and w.bgNPC.Actors.Count() == 0, 'delayed initialization cannot resurrect a retired client UID')
  check((BGN_ACTOR and BGN_ACTOR.BaseClass) == original_factory, 'test worlds preserve the live compatibility factory')
end)

bgNPC.Test.Add('audit.spawn_appearance', function(check)
  local w = World()
  local data = {
    class = 'npc_citizen',
    random_skin = true,
    random_bodygroups = true
  }

  local npc = {
    valid = true,
    SkinCount = function() return 2 end,
    GetBodygroupCount = function() return 3 end,
    GetBodyGroups = function()
      return {
        {
          id = 0
        }
      }
    end,
    SetPos = function() end,
    SetSpawnEffect = function() end,
    Spawn = function() end,
    SetOwner = function() end,
    Activate = function() end,
    PhysWake = function() end
  }

  function npc:SetSkin(value)
    self.skin = value
  end

  function npc:SetBodygroup(_, value)
    self.group = value
  end

  local created = 0
  w.ents = {
    Create = function()
      created = created + 1
      return npc
    end
  }

  w.player = {
    GetCount = function() return 1 end
  }

  w.game = {
    GetWorld = function() return {} end
  }

  w.list = {
    Get = function() return {} end
  }

  w.bgNPC.Util = {
    Chance = function() return false end,
    IsVectorInWater = function() return false end
  }

  w.bgNPC.Config.GetActor = function() return data end
  w.bgNPC.cfg = {
    actors = {
      citizen = data
    }
  }

  w.bgNPC.SpawnMenu = {
    Creator = {
      NPC = {}
    }
  }

  w.bgNPC.NextBotBody = {
    ResolveClass = function(class) return class end
  }

  w.bgNPC.Actor = {
    Create = function(ent) return ent end
  }

  w.GetConVar = function()
    return {
      GetFloat = function() return 100 end,
      GetBool = function() return false end
    }
  end

  w.Load('spawner/sv_spawner.lua')
  w.bgNPC.NPCIsStuck = function() return false end
  local skin
  w.hook.Run = function(event, value) if event == 'BGN_PreSetActorSkin' then skin = value end end
  -- Repeated samples exercise both inclusive bounds and the exact value approved by the hook.
  for _ = 1, 50 do
    w.bgNPC:SpawnActor('citizen', Vector())
    check(npc.skin == skin and skin >= 0 and skin < 2 and npc.group >= 0 and npc.group < 3, 'appearance indices are valid and the approved skin is applied')
  end

  local owner = {
    valid = true,
    IsPlayer = function() return true end,
    Alive = function() return true end,
    IsAdmin = function() return false end
  }

  local denied, spawned, checked_class = true, 0, nil
  w.hook.Run = function(event, _, class)
    if event == 'PlayerSpawnNPC' then
      checked_class = class
      return not denied
    end

    if event == 'PlayerSpawnedNPC' then spawned = spawned + 1 end
  end

  function npc:SetCreator(ply)
    self.creator = ply
  end

  local before = created
  check(not w.bgNPC:SpawnActor('citizen', Vector(), false, false, owner) and created == before, 'gamemode denial precedes entity creation')
  denied = false
  check(w.bgNPC:SpawnActor('citizen', Vector(), false, false, owner) == npc and spawned == 1 and npc.creator == owner and checked_class == 'npc_citizen', 'player spawn uses the actual class and standard count/ownership hook')
  before = created
  owner.Alive = function() return false end
  check(not w.bgNPC:SpawnActor('citizen', Vector(), false, false, owner) and created == before, 'dead non-admin cannot bypass spawn restrictions')
  check(not w.bgNPC:SpawnActor('citizen', Vector(), false, false, {}) and created == before, 'invalid owner is rejected before creation')
end)

bgNPC.Test.Add('audit.string_uid_lod', function(check)
  local w = World()
  w.GetConVar = function()
    return {
      GetFloat = function() return 500 end
    }
  end

  w.player = {
    GetAll = function() return {} end
  }

  w.util.CRC = function() return '123' end
  w.bgNPC.Util = {
    IsInView = function() return false end
  }

  local actor = {
    uid = 'custom-character',
    npc = {
      valid = true
    },
    start_think = true
  }

  function actor:GetNPC()
    return self.npc
  end

  function actor:GetPos()
    return Vector()
  end

  function actor:HasState()
    return false
  end

  function actor:IsAlive()
    return true
  end

  function actor:InVehicle()
    return false
  end

  function actor:HasActiveWeapon()
    return false
  end

  function actor:EnemiesRecalculate()
  end

  function actor:RecalculationTargets()
  end

  function actor:UpdateMovement()
  end

  actor.body = {
    SetThinkEnabled = function() end
  }

  actor.brain = {
    Update = function() end
  }

  w.bgNPC.Actors.GetAll = function() return {actor} end
  w.Load('actor/update/sv_actor_update.lua')
  w.Resume('BGN_ActorUpdate')
  check(actor.lod_phase == 123 and actor.uid == 'custom-character', 'LOD uses a stable numeric phase without changing a custom UID')
end)

bgNPC.Test.Add('audit.vehicle_missing_model', function(check)
  local w = World()
  w.bgNPC.Actor = {}
  w.bgNPC.Combat = {
    ResolveVehicleAttacker = function() end,
    IsAttacker = function() return false end
  }

  w.bgNPC.Actors.GetAll = function() return {} end
  w.bgNPC.Actors.Get = function() end
  w.GetConVar = function()
    return {
      GetFloat = function() return 0 end
    }
  end

  w.Load('actor/components/sh_vehicle.lua')
  local model = {
    valid = false
  }

  for _, name in ipairs({'GetNWEntity', 'GetVehicleForward', 'GetPos'}) do
    model[name] = function() error('NULL entity: ' .. name) end
  end

  local car = {
    valid = true
  }

  function car:GetModelBounds()
    return Vector(-100, -50, 0), Vector(100, 50, 80)
  end

  function car:GetPos()
    return Vector(1000, 0, 0)
  end

  function car:GetForward()
    return Vector(1, 0, 0)
  end

  function car:GetUp()
    return Vector(0, 0, 1)
  end

  function car:GetAngles()
    return Angle()
  end

  function car:LocalToWorld(pos)
    return self:GetPos() + pos
  end

  local provider = {
    IsValid = function() return true end,
    GetVehicle = function() return car end
  }

  local saved = {
    health = 37,
    mins = Vector(-16, -16, 0),
    maxs = Vector(16, 16, 72),
    model = 'original.mdl',
    bodygroups = {}
  }

  local actor = setmetatable({
    uid = 'crew',
    npc = model,
    vehicle = provider,
    vehicle_body = saved,
    enemies = {}
  }, {
    __index = w.bgNPC.Actor
  })

  function actor:GetNPC()
    return self.npc
  end

  function actor:Health()
    return saved.health
  end

  function actor:GetAngles()
    return Angle()
  end

  function actor:HasState()
    return false
  end

  function actor:GetEnemy()
  end

  function actor:CreateFakePlayerMethodsForNPC()
  end

  function actor:Remove()
    self.is_removed = true
  end

  local traces = 0
  w.util.TraceLine = function(data)
    traces = traces + 1
    check(data.filter[1] == car, 'the chassis remains in the trace filter without a model')
    return {
      Hit = true,
      HitNormal = Vector(0, 0, 1),
      HitPos = Vector(data.start.x, data.start.y, 0)
    }
  end

  w.util.TraceHull = function()
    return {
      Hit = true
    }
  end

  w.util.IsInWorld = function() return true end
  check(not actor:ExitVehicle(true) and actor.vehicle_body == saved and traces > 0, 'missing visual still searches exits; blocked geometry retains the character')
  local corpse_pos, deaths = nil, 0
  w.util.TraceHull = function()
    return {
      Hit = false
    }
  end

  local function Body()
    return setmetatable({
      valid = true,
      SetPos = function(_, pos) corpse_pos = pos end
    }, {
      __index = function() return function() end end
    })
  end

  local restored_health, detached
  saved.class, saved.keyvalues, saved.weapons = 'npc_citizen', {}, {}
  w.ents = {
    Create = function(class)
      check(class == saved.class, 'exit restores the original body class')
      local npc = Body()
      npc.SetHealth = function(_, hp) restored_health = hp end
      return npc
    end
  }

  w.bgNPC.Actors.Rebind = function(a, npc) a.npc = npc end
  provider.driver = actor
  function provider:SetDriver(value)
    detached = value == nil
  end

  check(actor:ExitVehicle(true) and actor.uid == 'crew' and restored_health == 37 and detached and not actor.vehicle_body, 'forced exit restores stored health and keeps identity after model removal')
  actor.npc, actor.vehicle, actor.vehicle_body = model, provider, saved
  w.ents = {
    Create = function(class)
      check(class == 'prop_ragdoll', 'lethal damage creates the original character corpse')
      return Body()
    end
  }

  w.hook.Run = function(name) if name == 'OnNPCKilled' then deaths = deaths + 1 end end
  actor:TakeVehicleDamage(100)
  check(actor.is_removed and deaths == 1 and corpse_pos.x == 1000 and corpse_pos.z == 2, 'lethal damage works after visual removal and leaves the corpse beside the car')
  actor:TakeVehicleDamage(100)
  check(deaths == 1, 'a removed character cannot die twice')
end)

bgNPC.Test.Add('audit.wanted_missing_observer', function(check)
  local w = World()
  local detections, refreshes = 0, 0
  local enemy = {
    valid = true,
    IsPlayer = function() return true end,
    GetPos = function() return Vector() end
  }

  local wanted = {
    target = enemy,
    time_reset = 100,
    UpdateWaitTime = function() end,
    UpdateWanted = function() refreshes = refreshes + 1 end
  }

  local asset = {
    GetAllWanted = function() return {wanted} end,
    ClearDeath = function() end
  }

  local arrest = {
    IsProtected = function() return false end
  }

  w.bgNPC.Modules = {
    Get = function(name)
      if name == 'wanted' then
        return asset
      elseif name == 'player_arrest' then
        return arrest
      end
    end
  }

  w.bgNPC.Modes = {
    IsPeaceful = function() return false end
  }

  w.GetConVar = function()
    return {
      GetBool = function() return true end,
      GetInt = function() return 0 end,
      GetFloat = function() return 0 end
    }
  end

  local function Observer(valid, alive)
    local npc = {
      valid = valid,
      GetPos = function()
        check(valid, 'NULL observer must not be queried')
        return Vector()
      end
    }
    return {
      IsAlive = function() return alive end,
      GetNPC = function() return npc end,
      HasTeam = function() return false end,
      EqualStateGroup = function() return true end,
      HasState = function() return false end,
      AddEnemy = function() detections = detections + 1 end
    }
  end

  local observers = {Observer(false, true), Observer(true, false), Observer(true, true)}
  w.bgNPC.Actors.GetByTeam = function() return observers end
  w.Load('systems/wanted/sv_wanted_actions.lua')
  local update = w.timers.BGN_Timer_CheckingTheWantesStatusOfTargets
  update()
  check(detections == 1 and refreshes == 1, 'only a living observer with a current entity can refresh wanted status')
  observers[3] = nil
  update()
  check(detections == 1 and refreshes == 1, 'an actor awaiting a replacement body cannot refresh wanted status alone')
end)

bgNPC.Test.Add('audit.relationship_missing_body', function(check)
  local w = World()
  local wanted_mode = false
  w.GetConVar = function(name)
    return {
      GetBool = function() return name == 'bgn_enable_wanted_mode' and wanted_mode end
    }
  end

  local npc, calls = {
    valid = false
  }, 0

  local actor = {
    IsAlive = function() return true end,
    GetNPC = function() return npc end,
    HasEnemy = function() return true end
  }

  local foreign = {
    valid = true,
    IsNPC = function() return true end,
    Health = function() return 100 end
  }

  function foreign:Disposition(target)
    check(w.IsValid(target), 'hostility polling cannot pass a removed body to the engine')
    calls = calls + 1
    return D_HT
  end

  w.bgNPC.Modes = {
    IsPeaceful = function() return false end
  }

  w.bgNPC.Modules = {
    Get = function()
      return {
        AddWanted = function() npc.valid = false end
      }
    end
  }

  w.bgNPC.Combat = {
    IsIgnored = function() return false end
  }

  w.bgNPC.Actors.Get = function() end
  w.bgNPC.Actors.GetAll = function() return {actor} end
  w.ents = {
    GetAll = function() return {foreign} end
  }

  w.Load('systems/sv_relationship.lua')
  local poll = w.timers.BGN_SpotHostileNPC
  poll()
  check(calls == 0, 'missing occupants do not participate in disposition queries')
  npc.valid = true
  poll()
  check(calls == 1, 'valid occupants remain eligible for hostility checks')
  wanted_mode = true
  actor.HasTeam = function() return true end
  actor.HasEnemy = function() return false end
  npc.GetPos = function() error('wanted callback removed the body') end
  poll()
  check(not npc.valid and calls == 2, 'wanted callbacks may remove an observer during polling')
end)

for name, path in pairs({
  BGN_ActorsRegeneration = 'systems/npcs/sv_regeneration.lua',
  BGN_ActorsResidentsRandomVoice = 'systems/npcs/sv_random_voice.lua',
  BGN_Timer_ActorLookAtObject = 'systems/sv_npc_look_at_object.lua'
}) do
  bgNPC.Test.Add('audit.missing_body_' .. name, function(check)
    local w = World()
    local npc = {
      valid = false
    }

    local calls = 0
    for _, method in ipairs({'EmitSound', 'IsEFlagSet', 'GetPos'}) do
      npc[method] = function()
        check(npc.valid, 'engine access after body removal: ' .. method)
        calls = calls + 1
        if method == 'GetPos' then return Vector() end
        return false
      end
    end

    local actor = {
      IsAlive = function() return true end,
      GetNPC = function() return npc end,
      EqualStateGroup = function() return true end,
      GetData = function() return {} end
    }

    w.bgNPC.Actors.GetAll = function() return {actor} end
    w.bgNPC.Actors.GetByTeam = w.bgNPC.Actors.GetAll
    w.bgNPC.Table = {
      Random = function(t) return t[1] end
    }

    w.bgNPC.Util = {
      Chance = function() return true end
    }

    w.ents = {
      FindInSphere = function()
        return {
          {
            valid = true,
            GetPos = function() return Vector() end
          }
        }
      end
    }

    w.bgNPC.Tasks.Budget = coroutine.yield
    w.bgNPC.Vision = {
      NPCCanSeePos = function() error('scan continued after its body disappeared during a budget yield') end
    }

    w.Load(path)
    check(w.Resume(name) == 'suspended' and calls == 0, 'a missing body does not terminate the service')
    npc.valid = true
    w.Load(path)
    w.Resume(name)
    check(calls > 0, 'the service resumes engine work when a body is available')
    npc.valid = false
    check(w.Resume(name) == 'suspended', 'body removal across a yield is safe')
  end)
end
