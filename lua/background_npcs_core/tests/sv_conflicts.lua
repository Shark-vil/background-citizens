-- Isolated hooks/modules: these tests never create entities or alter live gameplay state.
local function World()
  local env = setmetatable({now = 100, seen = true, in_view = true, SERVER = true, CLIENT = false}, {__index = _G})
  local hooks, modules, timers, actors, humans = {}, {}, {}, {}, {}
  local values = {bgn_enable_wanted_mode = 1, bgn_arrest_mode = 1, bgn_arrest_time_limit = 20,
    bgn_wanted_police_instantly = 1, bgn_wanted_impunity_limit = 5, bgn_wanted_impunity_reduction_period = 10}
  env.IsValid = function(ent) return type(ent) == 'table' and ent.valid == true end
  env.CurTime = function() return env.now end
  env.GetConVar = function(name)
    return {GetBool = function() return (values[name] or 0) ~= 0 end,
      GetInt = function() return values[name] or 0 end, GetFloat = function() return values[name] or 0 end}
  end
  env.hook = {Add = function(event, id, fn) hooks[event] = hooks[event] or {} hooks[event][id] = fn end}
  env.hook.Run = function(event, ...)
    for _, fn in pairs(hooks[event] or {}) do
      local a, b = fn(...)
      if a ~= nil then return a, b end
    end
  end
  env.timer = {Create = function(id, _, _, fn) timers[id] = fn end, Simple = function(_, fn) fn() end}
  env.list = {Set = function(_, name, value) modules[name] = value end}
  env.cvars = {AddChangeCallback = function() end}
  env.player = {GetHumans = function() local result = {} for i, ent in ipairs(humans) do result[i] = ent end return result end, GetAll = function() return humans end}
  env.ents = {GetAll = function() return env.entities end}
  env.entities = {}
  env.bgNPC = {Actor = {}, Combat = {IsIgnored = function(ent) return ent.ignored end}, Assert = {Arg = function() end},
    Modes = {IsPeaceful = function() return env.peaceful end, IsFriend = function() return env.friendly end}, Modules = {Get = function(name) return modules[name] end},
    Actors = {Get = function(ent) return ent and ent.actor end, GetAll = function() return actors end,
      GetInRadius = function() return actors end, GetByTeam = function() return {} end},
    Vision = {HasLineOfSight = function(_, ent) return env.seen and ent.visible ~= false end},
    Util = {IsInView = function() return env.in_view end, CanSeeEntity = function() return env.seen end, Log = function() end},
    Statistics = {GetSum = function(ent) return ent.kills or 0 end, Reset = function(ent) ent.kills = nil end},
    Net = {Send = function() end}, NextBotBody = {GetPlayersDisposition = function() return D_NU end}}
  env.states = {}
  env.bgNPC.States = {Register = function(name, _, state) env.states[name] = state end}
  env.bgNPC.Util.Chance = function() return false end
  local wanted = {}
  modules.wanted = {
    AddWanted = function(_, ent) wanted[ent] = true end,
    HasWanted = function(_, ent) return wanted[ent] end,
    GetAllWanted = function() return {} end,
    GetWanted = function() return {UpdateWanted = function() end, next_kill_update = math.huge} end
  }
  modules.team_parent = {HasParent = function() return false end}
  function env.Load(path)
    local chunk = assert(CompileFile('background_npcs_core/' .. path))
    setfenv(chunk, env)()
  end
  function env.Entity(kind)
    local ent = {valid = true, health = 100, pos = Vector(), kind = kind or 'npc'}
    function ent:IsPlayer() return self.kind == 'player' end
    function ent:IsNPC() return self.kind == 'npc' end
    function ent:IsNextBot() return self.kind == 'nextbot' end
    function ent:IsVehicle() return false end
    function ent:Health() return self.health end
    function ent:GetMaxHealth() return 100 end
    function ent:GetPos() return self.pos end
    function ent:EyePos() return self.pos - Vector(1, 0, 0) end
    function ent:GetForward() return Vector(env.in_view and 1 or -1, 0, 0) end
    function ent:WorldSpaceCenter() return self.pos end
    if ent:IsPlayer() then humans[#humans + 1] = ent end
    env.entities[#env.entities + 1] = ent
    return ent
  end
  function env.Actor(team, kind)
    local actor = {npc = env.Entity(kind), uid = #actors + 1, team = team or {}, enemies = {}, data = {}, mechanics = {call_for_help = true}}
    actor.npc.actor = actor
    function actor:GetNPC() return self.npc end
    function actor:IsAlive() return self.npc.valid and self.npc.health > 0 end
    function actor:GetMaxHealth() return 100 end
    function actor:HasState(state) return self.state == state end
    function actor:GetStateData() return self.state_data or {} end
    function actor:HasTeam(other)
      if type(other) == 'string' then return self.team[other] == true end
      other = other and (other.actor or other)
      for name in pairs(self.team) do if other and other.team and other.team[name] then return true end end
      return false
    end
    function actor:HasEnemy(ent) return self.enemies[ent.actor and ent or ent.npc or ent] end
    function actor:AddEnemy(ent) self.enemies[ent] = true end
    function actor:RemoveAllTargets() self.target = nil end
    function actor:AddTarget(ent) self.target = ent end
    function actor:RemoveTarget() end
    function actor:SetState(state) self.state = state end
    function actor:InVehicle() return false end
    function actor:EqualStateGroup() return false end
    function actor:GetRelationship() end
    function actor:GetBody() return self.body end
    function actor:GetReactionForProtect() return 'defense' end
    function actor:SetReaction(reaction) self.reaction = reaction end
    function actor:GetLastReaction() return self.reaction or 'fear' end
    function actor:FearScream() end
    actors[#actors + 1] = actor
    return actor
  end
  function env.Damage(attacker, amount)
    return {GetAttacker = function() return attacker end, GetDamage = function() return amount or 1 end}
  end
  env.Load('api/sv_combat.lua')
  env.Load('systems/arrest/sv_arrest.lua')
  env.Load('systems/sv_first_attacker_found.lua')
  return env, modules, timers, wanted, values
end

bgNPC.Test.Add('conflicts.initiator_and_resets', function(check)
  local w, modules = World()
  local first = modules.first_attacker
  local a, b, c = w.Entity('player'), w.Entity(), w.Entity()
  local damage = w.Damage(a)
  w.hook.Run('PostEntityTakeDamage', b, damage, false)
  check(#first:GetData() == 0, 'blocked damage creates no conflict')
  w.hook.Run('PostEntityTakeDamage', b, w.Damage(a, 0), true)
  check(#first:GetData() == 0, 'zero damage creates no conflict')
  w.hook.Run('PostEntityTakeDamage', b, damage, true)
  w.hook.Run('PostEntityTakeDamage', a, w.Damage(b), true)
  check(first:IsFirstAttacker(a, b) and not first:IsFirstAttacker(b, a) and #first:GetData() == 1, 'retaliation preserves the first direction')
  first:RecordDamage(b, c)
  check(first:IsFirstAttacker(b, c), 'a defender can initiate a different conflict')
  local replacement = w.Entity()
  w.hook.Run('BGN_ActorEntityChanged', nil, b, replacement)
  w.hook.Run('EntityRemoved', b)
  check(first:IsFirstAttacker(a, replacement) and first:IsFirstAttacker(replacement, c), 'both roles survive body replacement')
  w.hook.Run('BGN_RemoveWantedTarget', replacement)
  check(#first:GetData() == 0, 'wanted reset clears both roles')
  for _, event in ipairs({'PlayerDeath', 'PlayerSilentDeath', 'OnNPCKilled', 'BGN_PlayerArrest'}) do
    first:RecordDamage(a, c)
    w.hook.Run(event, c)
    check(#first:GetData() == 0, event .. ' clears victim records too')
  end
end)

bgNPC.Test.Add('police_call.proximity_only', function(check)
  local w, _, _, wanted, values = World()
  w.Sound = function(path) return path end
  w.EmitSound = function() end
  w.SoundDuration = function() return 2 end
  w.bgNPC.Table = {Random = function(items) return items[1] end}
  w.Load('brain/fsm/states/sv_calling_police.lua')
  local caller, enemy = w.Actor({residents = true}), w.Entity('player')
  caller.state = 'calling_police'
  caller.state_data = {calling_time = 110}
  caller.enemies = {enemy}
  enemy.pos = Vector(300, 0, 0)
  function caller:HasNoEnemies() return false end
  function caller:GetEnemy() return enemy end
  function caller:GetReactionForDamage() return 'fear' end
  function caller:HasSequence() return true end
  function caller.npc:EntIndex() return 1 end
  function caller:Voice() end
  function caller:CallForHelp() end
  w.seen = false
  wanted[enemy] = true
  local state = w.states.calling_police
  state.update(caller)
  check(caller.state == 'calling_police' and caller.state_data.calling_time == 110, 'LOS loss and wanted status do not cancel or restart the call at exactly 300')
  w.now = 111
  state.update(caller)
  check(caller.state == 'fear', 'the call finishes normally without LOS')
  caller.state = 'calling_police'
  caller.state_data = {calling_time = 130}
  enemy.pos = Vector(299, 0, 0)
  state.update(caller)
  check(caller.state == 'fear', 'a threat closer than 300 still interrupts')
  caller.state = 'calling_police'
  enemy.pos = Vector(400, 0, 0)
  values.bgn_enable_wanted_mode = 0
  state.update(caller)
  check(caller.state == 'fear', 'disabling wanted still exits safely')
end)

bgNPC.Test.Add('police_call.goap_does_not_interrupt', function(check)
  local w = World()
  local updated = false
  w.bgNPC.Class = function() return {} end
  w.bgNPC.GOAP = {}
  w.bgNPC.FSMBrain = {Update = function() updated = true end}
  w.bgNPC.Commands = {Register = function() end}
  w.bgNPC.Brain = {Register = function() end}
  w.Load('brain/goap/sv_goap_brain.lua')
  local caller = w.Actor({residents = true})
  function caller:HasNoEnemies() return false end
  function caller:GetState() return 'calling_police' end
  local brain = setmetatable({actor = caller, fighting = true}, {__index = w.bgNPC.GOAPBrain})
  brain:Update()
  check(updated, 'an active call runs its FSM without replanning it away')
end)

bgNPC.Test.Add('arrest.starts_after_damage', function(check)
  local w, modules, _, wanted = World()
  w.Load('brain/fsm/states/sv_arrest.lua')
  local police, suspect = w.Actor({police = true, residents = true}), w.Entity('player')
  w.hook.Run('PostEntityTakeDamage', police.npc, w.Damage(suspect), false)
  check(not modules.player_arrest:HasTarget(suspect), 'blocked hits do not start arrest')
  w.hook.Run('PostEntityTakeDamage', police.npc, w.Damage(suspect), true)
  check(modules.player_arrest:HasTarget(suspect) and not wanted[suspect], 'the opening hit starts arrest without escalating it')
  w.hook.Run('PostEntityTakeDamage', police.npc, w.Damage(suspect), true)
  check(wanted[suspect], 'a later police hit escalates')
end)

bgNPC.Test.Add('conflicts.foreign_hostility', function(check)
  local w, _, timers, wanted = World()
  w.Load('systems/sv_relationship.lua')
  local resident, foreign, player = w.Actor({residents = true}), w.Entity(), w.Entity('player')
  foreign.Disposition = function(_, target) return target == player and D_HT or D_NU end
  timers.BGN_SpotHostileNPC()
  check(not wanted[foreign] and not resident:HasEnemy(foreign), 'hostility towards players alone is not hostility towards actors')
  foreign.Disposition = function() return D_HT end
  foreign.pos = Vector(2501, 0, 0)
  timers.BGN_SpotHostileNPC()
  check(wanted[foreign] and not resident:HasEnemy(foreign), 'foreign hostility causes wanted without a witness, but local detection has a radius')
  foreign.pos = Vector() w.seen = false
  timers.BGN_SpotHostileNPC()
  check(not resident:HasEnemy(foreign), 'local enemy detection needs LOS')
  w.seen = true w.in_view = false
  timers.BGN_SpotHostileNPC()
  check(resident:HasEnemy(foreign), 'foreign hostility needs no FOV')
  local unknown = w.Entity('nextbot')
  timers.BGN_SpotHostileNPC()
  check(not wanted[unknown], 'entities without Disposition are not guessed hostile')
end)

bgNPC.Test.Add('conflicts.help_sees_caller', function(check)
  local w = World()
  w.Load('actor/components/sh_combat.lua')
  local source, ally, outsider = w.Actor({residents = true}), w.Actor({residents = true}), w.Actor({bandits = true})
  local enemy = w.Entity()
  enemy.visible = false
  w.bgNPC.Actor.CallForHelp(source, enemy)
  check(ally:HasEnemy(enemy) and not outsider:HasEnemy(enemy), 'visible caller shares a hidden enemy only with teammates')
  ally.enemies = {} source.npc.visible = false enemy.visible = true
  w.bgNPC.Actor.CallForHelp(source, enemy)
  check(not ally:HasEnemy(enemy), 'seeing only the enemy does not substitute for seeing the caller')
  source.npc.visible = true
  ally.state = 'calling_police'
  w.bgNPC.Actor.CallForHelp(source, enemy)
  check(ally.state == 'calling_police' and ally:HasEnemy(enemy), 'help adds threat knowledge without interrupting an active call')
end)

bgNPC.Test.Add('conflicts.damage_witnesses', function(check)
  local w = World()
  w.Load('actor/events/sv_damage_reaction.lua')
  local witness, victim = w.Actor({residents = true}), w.Actor({residents = true})
  local player = w.Entity('player')
  player.visible = false
  w.hook.Run('PostEntityTakeDamage', victim.npc, w.Damage(player), true)
  check(not witness:HasEnemy(player), 'a visible victim does not reveal an unseen attacker')
  player.visible = true w.in_view = false
  w.hook.Run('PostEntityTakeDamage', victim.npc, w.Damage(player), true)
  check(witness:HasEnemy(player), 'a visible player attack is noticed without FOV')
  local attacker = w.Actor({bandits = true}, 'nextbot')
  w.hook.Run('PostEntityTakeDamage', victim.npc, w.Damage(attacker.npc), true)
  check(not witness:HasEnemy(attacker.npc), 'a NextBot actor attack behind the witness is not noticed')
  w.in_view = true
  w.hook.Run('PostEntityTakeDamage', victim.npc, w.Damage(attacker.npc), true)
  check(witness:HasEnemy(attacker.npc), 'an actor attack in FOV is noticed')
end)

bgNPC.Test.Add('conflicts.forgetting', function(check)
  local w, modules = World()
  local first, a, b = modules.first_attacker, w.Entity(), w.Entity()
  first:RecordDamage(a, b)
  w.now = 200 first:ClearDeath()
  check(#first:GetData() == 1, 'visible participants remember the conflict')
  w.seen = false w.now = 259 first:ClearDeath()
  check(#first:GetData() == 1, 'less than 60 seconds unseen')
  first:RecordDamage(b, a)
  w.now = 318 first:ClearDeath()
  check(first:IsFirstAttacker(a, b), 'new damage extends memory without reversing roles')
  w.now = 319 first:ClearDeath()
  check(#first:GetData() == 0, '60 seconds without damage or contact forgets')
end)

bgNPC.Test.Add('conflicts.self_defense_and_visibility', function(check)
  local w, modules = World()
  local police = w.Actor({police = true, residents = true})
  local a, b = w.Entity('player'), w.Entity('nextbot')
  modules.first_attacker:RecordDamage(a, b)
  check(w.bgNPC.Combat.ResolveEnemy(police, a, b) == a, 'the original victim is not blamed for retaliation')
  check(w.bgNPC.Combat.ResolveEnemy(police, b, a) == a, 'the first attacker stays responsible')
  b.Disposition = function() return D_HT end
  check(w.bgNPC.Combat.ResolveEnemy(police, b, a) == b, 'a player may attack a hostile foreign NextBot')
  b.Disposition = nil
  check(w.bgNPC.Combat.ResolveEnemy(police, b, a) == a, 'missing Disposition is safe')
  local attacker = w.Actor({bandits = true}, 'nextbot')
  w.in_view = false
  check(not w.bgNPC.Combat.CanWitness(police, attacker.npc), 'actor attacks need FOV for NextBot bodies too')
  check(w.bgNPC.Combat.CanWitness(police, a), 'player attacks need no FOV')
  a.visible = false
  check(not w.bgNPC.Combat.CanWitness(police, a), 'seeing a victim cannot substitute for seeing the attacker')
  a.visible = true a.pos = Vector(2501, 0, 0)
  check(not w.bgNPC.Combat.CanWitness(police, a), 'witness radius is bounded')
end)

bgNPC.Test.Add('conflicts.common_enemy', function(check)
  local w, modules = World()
  w.Load('actor/events/sv_damage_reaction.lua')
  w.Load('brain/fsm/states/sv_arrest.lua')
  local police, resident, gangster = w.Actor({residents = true, police = true}), w.Actor({residents = true}), w.Actor({bandits = true})
  local player = w.Entity('player')
  for _, actor in ipairs({police, resident, gangster}) do actor:AddEnemy(player) end
  check(w.bgNPC.Combat.IsEnemyOfTeam(police, player), 'the observing officer counts its own enemy list')
  w.hook.Run('PostEntityTakeDamage', player, w.Damage(gangster.npc), true)
  check(not police:HasEnemy(gangster.npc) and not resident:HasEnemy(gangster.npc), 'the first hit on a shared enemy does not incriminate the gangster')
  check(not modules.player_arrest:HasTarget(gangster.npc), 'arrest initiation cannot bypass the common-enemy rule')
  check(modules.first_attacker:IsFirstAttacker(gangster.npc, player), 'the factual initiator is still recorded')
  w.hook.Run('PostEntityTakeDamage', gangster.npc, w.Damage(player), true)
  check(not police:HasEnemy(gangster.npc) and not resident:HasEnemy(gangster.npc), 'retaliation by the shared enemy does not turn the original shooter into an enemy')
  local innocent = w.Actor({residents = true})
  w.hook.Run('PostEntityTakeDamage', innocent.npc, w.Damage(gangster.npc), true)
  check(modules.player_arrest:HasTarget(gangster.npc), 'attacking an innocent ally is a separate offense')
  local other = w.Actor({zombies = true})
  other:AddEnemy(player)
  local foreign = w.Entity('nextbot')
  check(w.bgNPC.Combat.ResolveEnemy(other, player, foreign) == nil, 'the rule applies outside residents/police and without Disposition')
end)

bgNPC.Test.Add('conflicts.common_enemy_hostility', function(check)
  local w, modules = World()
  local police, gangster, player = w.Actor({police = true}), w.Actor({bandits = true}, 'nextbot'), w.Entity('player')
  police:AddEnemy(player)
  modules.first_attacker:RecordDamage(gangster.npc, player)
  local C = w.bgNPC.Combat
  check(C.IsAttackingEnemy(police, player, gangster.npc), 'an unknown neutral attacker may attack the known enemy')
  police:AddEnemy(gangster.npc)
  check(not C.IsAttackingEnemy(police, player, gangster.npc) and C.ResolveEnemy(police, player, gangster.npc) == gangster.npc, 'an existing enemy is not forgiven')
  police.enemies[gangster.npc] = nil
  gangster:AddEnemy(police.npc)
  check(not C.IsAttackingEnemy(police, player, gangster.npc), 'reverse enemy lists prevent the exception')
  gangster.enemies[police.npc] = nil
  for _, side in ipairs({police.npc, gangster.npc}) do
    side.Disposition = function() return D_HT end
    check(not C.IsAttackingEnemy(police, player, gangster.npc) and C.ResolveEnemy(police, player, gangster.npc) == gangster.npc, 'entity D_HT in either direction prevents the exception')
    side.Disposition = nil
  end
  for _, side in ipairs({police, gangster}) do
    side.body = {GetDisposition = function() return D_HT end}
    check(not C.IsAttackingEnemy(police, player, gangster.npc), 'body D_HT in either direction includes NextBots')
    side.body = nil
    side.GetRelationship = function() return D_HT end
    check(not C.IsAttackingEnemy(police, player, gangster.npc), 'configured D_HT in either direction prevents the exception')
    side.GetRelationship = function() end
  end
  gangster.npc.Disposition = function() return D_FR end
  check(C.IsAttackingEnemy(police, player, gangster.npc), 'fear alone is not hatred')
  check(not C.IsAttackingEnemy(police, police.npc, gangster.npc), 'direct self-defense is not suppressed')
end)

bgNPC.Test.Add('arrest.common_enemy_harm', function(check)
  local w, modules, _, wanted = World()
  local police, suspect = w.Actor({police = true}), w.Entity('player')
  local arrest = modules.player_arrest
  arrest:AddTarget(suspect, police)
  for _ = 1, 4 do
    local victim = w.Actor({bandits = true})
    victim.npc.health = 10
    police:AddEnemy(victim.npc)
    w.hook.Run('PostEntityTakeDamage', victim.npc, w.Damage(suspect), true)
  end
  check(not wanted[suspect] and arrest:GetTarget(suspect).damage_count == 0, 'non-hostile damage to the primary officer enemies does not count as innocent harm')
  w.hook.Run('OnNPCKilled', w.Entity(), suspect)
  check(wanted[suspect], 'a kill during arrest remains a separate escalation condition')
end)

bgNPC.Test.Add('arrest.confirmed_harm_limits', function(check)
  local w, modules, _, wanted = World()
  local arrest = modules.player_arrest
  local police, suspect = w.Actor({police = true}), w.Entity('player')
  local function Start() arrest:RemoveTarget(suspect) arrest:AddTarget(suspect, police) wanted[suspect] = nil end
  local victims = {}
  for i = 1, 4 do victims[i] = w.Actor({residents = true}) end
  w.hook.Add('BGN_ConfirmedDamage', 'start', function() if not arrest:HasTarget(suspect) then arrest:AddTarget(suspect, police) end end)
  w.hook.Run('PostEntityTakeDamage', police.npc, w.Damage(suspect), true)
  check(not wanted[suspect], 'the hit starting an arrest is not a later attack')
  for i = 1, 3 do
    for _ = 1, 2 do w.hook.Run('PostEntityTakeDamage', victims[i].npc, w.Damage(suspect), true) end
  end
  check(not wanted[suspect] and arrest:GetTarget(suspect).damage_count == 3, 'repeat hits count once; three victims permit arrest')
  w.hook.Run('PostEntityTakeDamage', victims[4].npc, w.Damage(suspect), true)
  check(wanted[suspect], 'the fourth unique victim escalates')
  Start() victims[1].npc.health = 30
  w.hook.Run('PostEntityTakeDamage', victims[1].npc, w.Damage(suspect), true)
  check(not wanted[suspect], 'exactly 30 percent is not below 30 percent')
  victims[1].npc.health = 29
  w.hook.Run('PostEntityTakeDamage', victims[1].npc, w.Damage(suspect), true)
  check(wanted[suspect], 'below 30 percent escalates')
  Start() modules.first_attacker:RemoveAttacker(suspect)
  modules.first_attacker:RecordDamage(victims[1].npc, suspect)
  w.hook.Run('PostEntityTakeDamage', victims[1].npc, w.Damage(suspect), true)
  check(not wanted[suspect] and arrest:GetTarget(suspect).damage_count == 0, 'retaliation against the initiator does not count')
  w.hook.Run('PostEntityTakeDamage', police.npc, w.Damage(suspect), true)
  check(wanted[suspect], 'hitting a police actor escalates')
  Start() w.hook.Run('OnNPCKilled', w.Entity(), suspect)
  check(wanted[suspect], 'killing a foreign NPC during arrest escalates')
  Start()
  local component, replacement = arrest:GetTarget(suspect), w.Entity()
  component.damage_count = 2
  w.hook.Run('BGN_ActorEntityChanged', nil, suspect, replacement)
  check(not arrest:HasTarget(suspect) and arrest:GetTarget(replacement) == component and component.damage_count == 2, 'body replacement preserves the arrest attempt and victim count')
end)

bgNPC.Test.Add('arrest.escape_and_refusal', function(check)
  local w, modules, _, wanted = World()
  local arrest, police, suspect = modules.player_arrest, w.Actor({police = true}), w.Entity('player')
  police.npc.pos = Vector(500, 0, 0)
  arrest:AddTarget(suspect, police)
  arrest:CheckCompliance(suspect, police)
  suspect.pos = Vector(-100, 0, 0) arrest:CheckCompliance(suspect, police)
  check(not wanted[suspect], 'no escape before the officer reaches the zone')
  police.npc.pos = Vector(150, 0, 0) arrest:CheckCompliance(suspect, police)
  police.npc.pos = Vector(500, 0, 0) arrest:CheckCompliance(suspect, police)
  check(not wanted[suspect], 'the officer moving away is not an escape')
  suspect.pos = Vector(-102, 0, 0) arrest:CheckCompliance(suspect, police)
  check(wanted[suspect], 'the suspect leaving the established zone escapes')
  local actor = w.Actor({bandits = true}, 'nextbot')
  arrest:AddTarget(actor.npc, police)
  w.now = 121 arrest:CheckCompliance(actor.npc, police)
  check(wanted[actor.npc], 'actor refusal has the same time limit as player refusal')
end)

bgNPC.Test.Add('wanted.players_actors_and_foreign', function(check)
  local w, _, timers, wanted = World()
  w.Load('systems/wanted/sv_wanted_actions.lua')
  local police, citizen = w.Actor({police = true, residents = true}), w.Actor({residents = true})
  local killer = w.Actor({bandits = true}, 'nextbot')
  for _ = 1, 4 do w.hook.Run('BGN_OnKilledActor', citizen, killer.npc) end
  check(not wanted[killer.npc] and killer.npc.bgn_wanted_module_impunity == 4, 'actors share the player threshold')
  timers.BGN_Timer_ResetPlayersImpunityLimit()
  check(killer.npc.bgn_wanted_module_impunity == 3, 'actor impunity decays too')
  for _ = 1, 2 do w.hook.Run('BGN_OnKilledActor', citizen, killer.npc) end
  check(wanted[killer.npc], 'the fifth remembered kill escalates')
  local player = w.Entity('player')
  local killed_police = w.Actor({police = true})
  killed_police.npc.health = 0
  police.team.police = nil
  w.hook.Run('BGN_OnKilledActor', killed_police, player)
  check(not wanted[player], 'a non-police witness cannot trigger instant police-kill wanted')
  police.team.police = true
  w.hook.Run('BGN_OnKilledActor', citizen, player)
  check(not wanted[player], 'ordinary kills still use the threshold')
  w.hook.Run('BGN_OnKilledActor', killed_police, player)
  check(wanted[player], 'a police witness triggers instant police-kill wanted')
  local foreign = w.Entity()
  w.seen = false
  w.hook.Run('BGN_OnKilledActor', citizen, foreign)
  check(wanted[foreign], 'a foreign killer needs no witness')
end)
