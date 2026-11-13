-- Isolated DATA and entities: never change the live weapon list or population.
local function World(raw)
  local w = setmetatable({enabled = false, reads = 0, writes = 0, errors = 0, disk = raw}, {__index = _G})
  local actors, entities, hooks, timers = {}, {}, {}, {}
  w.IsValid = function(ent) return istable(ent) and ent.valid == true end
  w.ErrorNoHalt = function() w.errors = w.errors + 1 end
  w.GetConVar = function() return {GetBool = function() return w.enabled end} end
  w.file = {
    Read = function() w.reads = w.reads + 1 return w.disk end,
    Write = function(_, value) w.writes = w.writes + 1 if w.fail_write then return false end w.disk = value return true end,
  }
  w.hook = {Add = function(event, id, fn) hooks[event] = hooks[event] or {} hooks[event][id] = fn end}
  w.timer = {Create = function(id, period, _, fn) assert(period == 1) timers[id] = fn end}
  w.ents = {GetAll = function() return entities end}
  w.bgNPC = {Assert = {Arg = function() end}, Util = {}, Modules = {}, Combat = {}, Actors = {
    Get = function(ent) return ent and ent.actor end, GetAll = function() return actors end,
  }, Modes = {IsPeaceful = function() return w.peaceful end, IsFriend = function() return w.friendly end},
    Vision = {HasLineOfSight = function(_, ent) return ent.visible ~= false end}}
  local function Load(path)
    setfenv(assert(CompileFile('background_npcs_core/' .. path)), w)()
  end
  Load('api/sv_combat.lua')
  w.bgNPC.Combat.IsIgnored = function(ent) return ent.ignored end
  function w.Reload() Load('systems/sv_lethal_weapons.lua') end
  function w.Tick() timers.BGN_ReactToLethalWeapon() end
  function w.Entity(kind, x)
    local ent = {valid = true, kind = kind or 'npc', pos = Vector(x or 0, 0, 0), forward = Vector(1, 0, 0), health = 100}
    function ent:IsPlayer() return self.kind == 'player' end
    function ent:IsNPC() return self.kind == 'npc' end
    function ent:IsNextBot() return self.kind == 'nextbot' end
    function ent:IsVehicle() return self.kind == 'vehicle' end
    function ent:InVehicle() return self.in_vehicle end
    function ent:Health() return self.health end
    function ent:GetPos() return self.pos end
    function ent:EyePos() return self.pos end
    function ent:WorldSpaceCenter() return self.pos end
    function ent:GetAimVector() return self.forward end
    function ent:GetActiveWeapon() return self.weapon end
    entities[#entities + 1] = ent
    return ent
  end
  function w.Weapon(ent, class)
    ent.weapon = {valid = true, GetClass = function() return class end}
  end
  function w.Actor(team, kind)
    local actor = {npc = w.Entity(kind), team = team or 'residents', enemies = {}, state = 'walk', picks = 0}
    actor.npc.actor = actor
    function actor:GetNPC() return self.npc end
    function actor:IsAlive() return self.npc.valid and self.npc.health > 0 end
    function actor:HasTeam(other) return other == self.team or (other.actor and other.actor.team == self.team) end
    function actor:HasEnemy(ent) return self.enemies[ent] end
    function actor:AddEnemy(ent) if not self.blocked then self.enemies[ent] = true end end
    function actor:GetReactionForDamage() self.picks = self.picks + 1 return self.pick or 'fear' end
    function actor:SetReaction(reaction) self.reaction = reaction end
    function actor:EqualStateGroup() return self.state == 'walk' end
    function actor:RemoveAllTargets() self.cleared = true end
    function actor:SetState(state) self.state = state end
    actors[#actors + 1] = actor
    return actor
  end
  function w.Hit(actor, attacker, blast, vehicle)
    local dmg = {GetAttacker = function() return attacker end, GetInflictor = function() return vehicle end,
      IsExplosionDamage = function() return blast end, IsDamageType = function() return vehicle ~= nil end}
    hooks.EntityTakeDamage.BGN_LethalWeaponDamage(actor.npc, dmg)
  end
  function w.Kill(actor, attacker) hooks.BGN_OnKilledActor.BGN_LearnLethalWeapon(actor, attacker) end
  w.Reload()
  return w
end

bgNPC.Test.Add('lethal_weapons.cache_and_learning', function(check)
  local w = World('{"weapon_old":true}')
  local victim, killer = w.Actor(), w.Entity('player')
  w.Weapon(killer, 'weapon_new')
  w.Hit(victim, killer)
  check(w.writes == 0, 'damage without a kill does not teach')
  w.Kill(victim, killer)
  local saved = util.JSONToTable(w.disk)
  check(saved.weapon_old and saved.weapon_new and w.writes == 1, 'learn while disabled and preserve loaded classes')
  w.Kill(victim, killer)
  w.Reload()
  w.enabled = true
  w.Tick()
  check(w.reads == 1 and w.writes == 1, 'duplicates, reload and polling do not reread or rewrite DATA')
  local fresh = World(w.disk)
  check(fresh.bgNPC.lethal_weapons.classes.weapon_new, 'a new server cache restores saved classes')
  killer.weapon.valid = false
  w.Kill(victim, killer)
  killer.GetActiveWeapon = false
  w.Kill(victim, killer)
  check(w.writes == 1, 'invalid weapon and missing getter are safe')
end)

bgNPC.Test.Add('lethal_weapons.excluded_kills_and_bad_data', function(check)
  local w = World()
  local victim, killer = w.Actor(), w.Entity('player')
  w.Weapon(killer, 'weapon_test')
  killer.in_vehicle = true
  w.Hit(victim, killer)
  killer.in_vehicle = false
  w.Kill(victim, killer)
  w.Hit(victim, killer, true)
  w.Kill(victim, killer)
  w.Hit(victim, killer, false, w.Entity('vehicle'))
  w.Kill(victim, killer)
  check(w.writes == 0, 'vehicle and explosion kills never teach')
  w.Hit(victim, killer)
  w.fail_write = true
  w.Kill(victim, killer)
  check(w.errors == 1 and w.bgNPC.lethal_weapons.classes.weapon_test, 'write failure reports an error but retains the cache')
  for _, raw in ipairs({'broken json', '{"weapon_old":false}'}) do
    local bad = World(raw)
    local a, e = bad.Actor(), bad.Entity()
    bad.Weapon(e, 'weapon_test')
    bad.Hit(a, e)
    bad.Kill(a, e)
    check(bad.errors == 1 and bad.disk == raw and bad.writes == 0, 'corrupt DATA is reported and preserved')
  end
end)

bgNPC.Test.Add('lethal_weapons.range_fov_and_reaction', function(check)
  for _, kind in ipairs({'player', 'npc', 'nextbot'}) do
    for _, body in ipairs({'npc', 'nextbot'}) do
      local w = World('{"weapon_test":true}')
      local actor, target = w.Actor('residents', body), w.Entity(kind, 800)
      w.Weapon(target, 'weapon_test')
      w.Tick()
      check(not actor:HasEnemy(target), 'disabled checkbox prevents reaction')
      w.enabled = true
      target.pos = Vector(801, 0, 0)
      w.Tick()
      target.pos = Vector(-800, 0, 0)
      w.Tick()
      target.pos = Vector(0, 800, 0)
      w.Tick()
      target.pos = Vector(800, 0, 0)
      target.visible = false
      w.Tick()
      check(actor.picks == 0, 'range, rear, FOV boundary and walls block reaction for both bodies')
      target.visible = true
      w.Tick()
      check(actor:HasEnemy(target) and actor.state == 'fear' and actor.cleared, '800 inclusive: damage reaction, enemy and state')
      target.weapon = nil
      w.Tick()
      w.enabled = false
      w.Tick()
      check(actor:HasEnemy(target) and actor.picks == 1, 'holstering and disabling do not clear enemies or reroll reactions')
    end
  end
end)

bgNPC.Test.Add('lethal_weapons.teams_and_guards', function(check)
  local w = World('{"weapon_test":true}')
  w.enabled = true
  local police, ally, civilian, bandit = w.Actor('police'), w.Actor('police'), w.Actor(), w.Actor('bandits')
  ally.npc.pos = Vector(50, 0, 0)
  w.Weapon(ally.npc, 'weapon_test')
  police.pick = 'defense'
  w.Tick()
  check(not police:HasEnemy(ally.npc) and civilian:HasEnemy(ally.npc) and not bandit:HasEnemy(ally.npc), 'shared teams excluded; only residents/police observe')
  local player = w.Entity('player', 100)
  w.Weapon(player, 'weapon_test')
  for _, flag in ipairs({'peaceful', 'friendly'}) do
    w[flag] = true w.Tick() w[flag] = false
    check(not police:HasEnemy(player), flag .. ' mode prevents player reactions')
  end
  player.ignored = true w.Tick() player.ignored = false
  police.blocked = true
  w.Tick()
  check(not police:HasEnemy(player) and police.state == 'walk', 'ignored players and rejected enemies do not start combat')
  police.blocked = false
  w.Tick()
  check(police:HasEnemy(player) and police.state == 'defense', 'police use their own damage reaction')
end)
