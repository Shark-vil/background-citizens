-- Real team/enemy/damage/wanted code in an isolated world; no live actors or timers.
local function World()
  local w = setmetatable({now = 100, SERVER = true, CLIENT = false, BGN_VEHICLE = false}, {__index = _G})
  local actors, modules, hooks = {}, {}, {}
  w.values = {bgn_team_damage = 0, bgn_enable_wanted_mode = 1, bgn_wanted_time = 30}
  w.IsValid = function(ent) return type(ent) == 'table' and ent.valid == true end
  w.isentity = function(ent) return type(ent) == 'table' and ent.entity == true end
  w.istable = function(value) return type(value) == 'table' and not w.isentity(value) end
  w.CurTime = function() return w.now end
  w.DamageInfo = function()
    local damage = {}
    function damage:SetDamage(value) self.amount = value end
    function damage:GetDamage() return self.amount end
    function damage:SetAttacker(value) self.attacker = value end
    function damage:GetAttacker() return self.attacker end
    function damage:SetInflictor(value) self.inflictor = value end
    function damage:GetInflictor() return self.inflictor end
    return damage
  end
  w.GetConVar = function(name) return {GetBool = function() return (w.values[name] or 0) ~= 0 end,
    GetFloat = function() return w.values[name] or 0 end, GetInt = function() return w.values[name] or 0 end} end
  w.hook = {Add = function(name, id, fn) hooks[name] = hooks[name] or {} hooks[name][id] = fn end}
  w.hook.Remove = function(name, id) if hooks[name] then hooks[name][id] = nil end end
  w.hook.Run = function(name, ...) for _, fn in pairs(hooks[name] or {}) do local result = fn(...) if result ~= nil then return result end end end
  w.timer = {Create = function() end, Simple = function() end}
  w.list = {Set = function(_, name, module) modules[name] = module end}
  w.cvars = {AddChangeCallback = function() end}
  w.Sound, w.EmitSound, w.SoundDuration = function(s) return s end, function() end, function() return 2 end
  w.player = {GetHumans = function() return {} end}
  w.bgNPC = {Actor = {Helpers = {}}, Assert = {Arg = function() end, NonEmptyString = function() end}, cfg = {wanted = {levels = {5}}},
    Modules = {Get = function(name) return modules[name] end}, Net = {Send = function() end},
    CVars = {OnChange = function() end}, Combat = {IsIgnored = function() return false end},
    Modes = {IsPeaceful = function() return false end, IsFriend = function() return false end},
    Util = {Log = function() end, Chance = function() return true end, CanSeeEntity = function() return true end},
    Vision = {HasLineOfSight = function() return true end, AnyActorSees = function() return true end},
    Statistics = {GetSum = function() return 0 end, Reset = function() end},
    Table = {HasValue = table.HasValue, IsArray = function(t) return #t > 0 end, Random = function(t) return t[1] end,
      HasWhere = function(t, fn) for k, v in pairs(t) do if fn(k, v) then return true end end return false end},
    Actors = {Get = function(ent) return ent and ent.actor end, GetAll = function() return actors end, GetInRadius = function() return actors end}}
  w.bgNPC.Actors.GetByTeam = function(team) local found = {} for _, a in ipairs(actors) do if a:HasTeam(team) then found[#found + 1] = a end end return found end
  w.states = {}
  w.bgNPC.States = {Register = function(name, _, def) w.states[name] = def end}
  modules.team_parent = {HasParent = function() return false end}
  function w.Load(path) setfenv(assert(CompileFile('background_npcs_core/' .. path)), w)() end
  function w.Entity(kind, x)
    local ent = {valid = true, entity = true, kind = kind or 'npc', pos = Vector(x or 0, 0, 0), health = 100}
    function ent:GetPos() return self.pos end
    function ent:Health() return self.health end
    function ent:GetMaxHealth() return 100 end
    function ent:IsPlayer() return self.kind == 'player' end
    function ent:IsNPC() return self.kind == 'npc' end
    function ent:IsNextBot() return self.kind == 'nextbot' end
    function ent:IsVehicle() return self.kind == 'vehicle' end
    function ent:EntIndex() return 1 end
    function ent:EmitSound() end
    return ent
  end
  w.Load('actor/components/sh_team.lua')
  w.Load('actor/components/sh_enemies.lua')
  w.Load('actor/components/sh_combat.lua')
  w.Load('api/sv_combat.lua')
  w.Load('api/sv_police_force.lua')
  w.Load('systems/arrest/sv_arrest.lua')
  w.Load('systems/wanted/sh_wanted_class.lua')
  w.Load('systems/sv_first_attacker_found.lua')
  w.Load('systems/sv_offender.lua')
  w.Load('actor/events/sv_self_damage.lua')
  w.Load('brain/fsm/states/sv_calling_police.lua')
  w.Load('systems/wanted/sv_wanted_actions.lua')
  function w.Actor(team, kind, x)
    local a = setmetatable({npc = w.Entity(kind, x), isBgnClass = true, uid = #actors + 1,
      data = {team = team}, state = 'idle', state_data = {}, enemies = {}, enemies_count = 0,
      enemies_always_visible = {}, enemies_always_visible_count = 0,
      mechanics = {enemies_controller = true, call_for_help = true}}, {__index = w.bgNPC.Actor})
    a.npc.actor = a
    function a:GetNPC() return self.npc end
    function a:GetPos() return self.npc:GetPos() end
    function a:GetData() return self.data end
    function a:IsAlive() return self.npc.health > 0 end
    function a:GetMaxHealth() return 100 end
    function a:IsCivilian() return self:HasTeam('residents') and not self:HasTeam('police') end
    function a:InVehicle() return self.car ~= nil end
    function a:GetVehicle() return self.car end
    function a:GetVehicleAI() return NULL end
    function a:HasState(state) return self.state == state end
    function a:EqualStateGroup(group) return group == 'calm' and self.state == 'idle' or group == 'danger' and self.state ~= 'idle' end
    function a:SetState(state) self.state = state end
    function a:RandomState() self.state = 'idle' end
    function a:GetStateData() return self.state_data end
    function a:GetReactionForProtect() return 'calling_police' end
    function a:GetReactionForDamage() return 'fear' end
    function a:SetReaction(state) self.reaction = state end
    function a:GetLastReaction() return self.reaction end
    function a:RemoveAllTargets() end
    function a:RemoveTarget() end
    function a:StayOutOfFight() self.stayed_out = true end
    function a:GetNearEnemy() return self.enemies[1] or NULL end
    a.body = {GetEnemy = function(body) return body.enemy or NULL end,
      SetEnemy = function(body, enemy) body.enemy = enemy end, SetDisposition = function() end, SetAlertLevel = function() end}
    actors[#actors + 1] = a
    return a
  end
  function w.Damage(attacker, kind, inflictor)
    return {GetAttacker = function() return attacker end, GetInflictor = function() return inflictor or attacker end,
      GetDamage = function() return 10 end, IsDamageType = function(_, flag) return kind == flag end}
  end
  function w.Car(driver)
    local car = w.Entity('vehicle')
    function car:GetDriver() return driver.npc end
    driver.car = car
    return car
  end
  w.modules = modules
  return w
end

bgNPC.Test.Add('teams.friendly_damage_has_no_combat_reaction', function(check)
  for _, kind in ipairs({'npc', 'nextbot'}) do
    for _, allow in ipairs({0, 1}) do
      local w = World()
      w.values.bgn_team_damage = allow
      local police, citizen = w.Actor({'residents', 'police'}, kind), w.Actor({'residents'}, kind)
      police:AddEnemy(w.Entity())
      local notifications = 0
      w.hook.Add('BGN_ConfirmedDamage', 'test', function() notifications = notifications + 1 end)
      local damage = w.Damage(police.npc, DMG_BULLET)
      local blocked = w.hook.Run('EntityTakeDamage', citizen.npc, damage)
      if blocked ~= true then w.hook.Run('PostEntityTakeDamage', citizen.npc, damage, true) end
      check(citizen.state == 'idle' and citizen:HasNoEnemies(), 'a friendly police bullet never starts civilian fear or adds another enemy')
      check(citizen.last_attacker == nil and citizen.last_attacked_at == nil, 'a friendly hit does not become a direct combat attacker')
      check(police.npc.bgn_last_attack == nil and not police.npc.bgn_ranged_attack, 'friendly damage does not record a combat attack')
      check(notifications == 0, 'allowed friendly health damage does not notify arrest or conflict witnesses')
      check((blocked == true) == (allow == 0), 'the team-damage switch controls health only')
    end
  end
end)

bgNPC.Test.Add('teams.team_change_clears_mutual_targets_and_wanted', function(check)
  local w = World()
  local police, suspect = w.Actor({'residents', 'police'}), w.Actor({'offenders'})
  police:AddEnemy(suspect.npc)
  suspect:AddEnemy(police.npc)
  w.modules.wanted:AddWanted(suspect.npc)
  suspect:SetTeam({'residents'})
  check(police:HasNoEnemies() and suspect:HasNoEnemies() and not w.IsValid(police.body:GetEnemy())
    and not w.IsValid(suspect.body:GetEnemy()), 'SetTeam clears both enemy lists and body targets immediately')
  check(not w.modules.wanted:HasWanted(suspect.npc), 'SetTeam clears resident wanted status immediately')
  suspect:SetTeam({'offenders'})
  w.modules.player_arrest:AddTarget(suspect.npc, police)
  police:AddEnemy(suspect.npc)
  suspect:AddTeam('residents')
  check(police:HasNoEnemies(), 'AddTeam applies the same reconciliation')
  check(not w.modules.player_arrest:HasTarget(suspect.npc), 'newly allied suspects leave an existing arrest')
end)

bgNPC.Test.Add('teams.ramming_requires_vehicle_source_and_resets_after_a_gap', function(check)
  local w = World()
  local driver, police_car = w.Actor({'residents'}), w.Entity('vehicle')
  local car = w.Car(driver)
  check(not w.bgNPC.OffenderFromRamming(driver.npc, w.Damage(driver.npc, DMG_CRUSH), police_car), 'a seated attacker alone does not prove a vehicle collision')
  w.bgNPC.OffenderFromRamming(driver.npc, w.Damage(car, DMG_CRUSH, car), police_car)
  w.now = 110
  check(not w.bgNPC.OffenderFromRamming(driver.npc, w.Damage(car, DMG_CRUSH, car), police_car)
    and driver:HasTeam('residents'), 'a long gap resets the police ramming timer')
  local other_car = w.Entity('vehicle')
  w.now = 112
  check(not w.bgNPC.OffenderFromRamming(driver.npc, w.Damage(car, DMG_CRUSH, car), other_car), 'changing the rammed car resets the timer')
end)

bgNPC.Test.Add('teams.help_cannot_spread_an_allied_enemy', function(check)
  local w = World()
  local caller, bystander, police = w.Actor({'residents'}), w.Actor({'residents'}), w.Actor({'residents', 'police'})
  caller:CallForHelp(police.npc)
  check(bystander.state == 'idle' and police.state == 'idle' and bystander:HasNoEnemies(), 'help cannot start a reaction against a shared teammate')
  w = World()
  caller, bystander, police = w.Actor({'residents'}), w.Actor({'residents', 'police'}), w.Actor({'police'})
  caller:CallForHelp(police.npc)
  check(bystander.state == 'idle' and bystander:HasNoEnemies(), 'the recipient also checks its own teams before changing state')
end)

bgNPC.Test.Add('teams.phone_and_wanted_reject_residents', function(check)
  local w = World()
  local caller, suspect = w.Actor({'residents'}), w.Actor({'offenders'}, 'npc', 600)
  caller:AddEnemy(suspect.npc)
  caller.state, caller.state_data = 'calling_police', {calling_time = 110}
  suspect:SetTeam({'residents'})
  local threat = w.Entity('npc', 700)
  caller:AddEnemy(threat)
  caller.enemies[#caller.enemies + 1] = suspect.npc -- model a stale snapshot from before the team change
  caller.enemies_count = #caller.enemies
  local reports, add_wanted = 0, w.modules.wanted.AddWanted
  w.modules.wanted.AddWanted = function(self, ent, ...)
    if ent == suspect.npc then reports = reports + 1 end
    return add_wanted(self, ent, ...)
  end
  w.now = 111
  w.states.calling_police.update(caller)
  check(reports == 0 and not w.modules.wanted:HasWanted(suspect.npc), 'a phone call cannot report an enemy that became a teammate during the call')
  check(w.modules.wanted:HasWanted(threat), 'a valid non-teammate is still reported by the same completed call')
  local police = w.Actor({'residents', 'police'})
  w.modules.wanted:AddWanted(police.npc)
  w.modules.wanted:AddWanted(suspect.npc)
  check(not w.modules.wanted:HasWanted(police.npc) and not w.modules.wanted:HasWanted(suspect.npc), 'the shared wanted entry point rejects resident/police actors')
  w.hook.Run('BGN_AddWantedTarget', suspect.npc)
  check(police.state == 'idle' and police:HasNoEnemies(), 'even an explicit wanted notification cannot start police combat against an ally')
end)

bgNPC.Test.Add('teams.stale_resident_wanted_is_removed', function(check)
  local w = World()
  local citizen = w.Actor({'residents'})
  table.insert(w.modules.wanted:GetAllWanted(), w.modules.wanted:Instance(citizen.npc))
  local police = w.Actor({'residents', 'police'})
  w.hook.Run('BGN_InitActor', police)
  check(police.state == 'idle' and police:HasNoEnemies(), 'a stale resident wanted entry cannot start combat in a new officer')
  w.modules.wanted:ClearDeath()
  check(not w.modules.wanted:HasWanted(citizen.npc), 'the regular cleanup removes a stale resident wanted entry')
end)

bgNPC.Test.Add('teams.police_on_foot_requires_repeated_vehicle_ramming', function(check)
  local w = World()
  local driver, police = w.Actor({'residents'}), w.Actor({'residents', 'police'})
  local car = w.Car(driver)
  w.hook.Run('EntityTakeDamage', police.npc, w.Damage(car, DMG_VEHICLE, car))
  check(driver:HasTeam('residents') and police:HasNoEnemies(), 'one collision with an officer on foot does not start a conflict')
  for now = 101, 103 do
    w.now = now
    w.hook.Run('EntityTakeDamage', police.npc, w.Damage(car, DMG_VEHICLE, car))
  end
  check(driver:HasTeam('offenders') and police:HasEnemy(driver.npc), 'repeated vehicle ramming of an officer keeps the explicit exception')
end)

bgNPC.Test.Add('teams.ramming_preserves_medic_and_peaceful_protection', function(check)
  local w = World()
  local medic = w.Actor({'residents', 'medics'})
  local car = w.Car(medic)
  check(not w.bgNPC.OffenderFromRamming(medic.npc, w.Damage(car, DMG_VEHICLE, car)) and medic:HasTeam('residents'), 'medics keep their existing protection')
  local driver = w.Actor({'residents'})
  car = w.Car(driver)
  w.bgNPC.Modes.IsPeaceful = function() return true end
  check(not w.bgNPC.OffenderFromRamming(driver.npc, w.Damage(car, DMG_VEHICLE, car)) and driver:HasTeam('residents'), 'peaceful mode never strips the residents team')
end)

bgNPC.Test.Add('teams.friendly_police_hits_do_not_execute_a_seated_citizen', function(check)
  local w = World()
  w.values.bgn_team_damage, w.values.bgn_police_car_kill_time = 1, 30
  w.Load('actor/components/sh_vehicle.lua')
  local citizen, police = w.Actor({'residents'}), w.Actor({'residents', 'police'})
  citizen.vehicle_body = {health = 100, police_hit_since = 0, police_hit_last = w.now}
  function citizen:Health() return self.vehicle_body.health end
  function citizen.npc:SetHealth(value) self.health = value end
  citizen:TakeVehicleDamage(1, police.npc, police.npc)
  check(citizen:Health() == 99 and citizen.state == 'idle' and citizen:HasNoEnemies(),
    'allowed friendly health damage never activates the police driver-execution timer')
end)

bgNPC.Test.Add('teams.ordinary_kill_does_not_remove_civilian_team', function(check)
  local w = World()
  local citizen, victim = w.Actor({'residents'}), w.Actor({'residents'})
  w.hook.Run('BGN_OnKilledActor', victim, citizen.npc)
  check(citizen:HasTeam('residents') and not citizen:HasTeam('offenders') and not w.modules.wanted:HasWanted(citizen.npc),
    'ordinary friendly kills cannot use the vehicle-only offender exception')
end)

bgNPC.Test.Add('teams.police_cannot_arrest_a_teammate', function(check)
  local w = World()
  local citizen, police = w.Actor({'residents'}), w.Actor({'residents', 'police'})
  check(w.modules.player_arrest:AddTarget(citizen.npc, police) == false, 'arrest registration rejects a teammate')
end)

bgNPC.Test.Add('teams.vehicle_exception_requires_a_real_collision', function(check)
  local w = World()
  local driver, police = w.Actor({'residents'}), w.Actor({'residents', 'police'})
  local car, police_car = w.Car(driver), w.Entity('vehicle')
  local provider = {GetVehicle = function() return police_car end, GetPassengers = function() return {police} end}
  w.bgNPC.DVCars = {provider}
  police.car = police_car
  function police:TakeVehicleDamage() end
  function police:ExitVehicle() end
  w.Load('modules/dv/sv_car_damage_reaction.lua')
  w.hook.Run('EntityTakeDamage', police_car, w.Damage(driver.npc, DMG_BULLET))
  check(driver:HasTeam('residents') and not w.modules.wanted:HasWanted(driver.npc), 'shooting the car is not a ramming exception, even while seated')
  w.hook.Run('EntityTakeDamage', police_car, w.Damage(car, DMG_CRUSH, car))
  check(driver:HasTeam('residents'), 'one accidental bump does not remove team protection')
  for now = 101, 103 do
    w.now = now
    w.hook.Run('EntityTakeDamage', police_car, w.Damage(car, DMG_CRUSH, car))
  end
  check(driver:HasTeam('offenders') and not driver:HasTeam('residents'), 'actual reacted-to vehicle ramming keeps its explicit exception')
  local pedestrian = w.Actor({'residents'})
  local other_driver = w.Actor({'residents'})
  local other_car = w.Car(other_driver)
  w.hook.Run('EntityTakeDamage', pedestrian.npc, w.Damage(other_car, DMG_VEHICLE, other_car))
  check(other_driver:HasTeam('offenders') and not other_driver:HasTeam('residents'), 'running over a civilian uses the vehicle exception before team protection')
end)
