-- Engine-free worlds: these tests do not modify live actors, cvars or timers.
local function World()
  local w = setmetatable({now = 100}, {__index = _G})
  local actors, callbacks = {}, {}
  w.values = {bgn_module_tactical_groups = 1}
  w.IsValid = function(ent) return istable(ent) and ent.valid == true end
  w.istable = function(value) return type(value) == 'table' and value.valid ~= true end
  w.CurTime = function() return w.now end
  w.GetConVar = function(name)
    return {GetBool = function() return (w.values[name] or 0) ~= 0 end, GetFloat = function() return w.values[name] or 0 end}
  end
  w.hook = {Add = function() end, Run = function() end}
  w.timer = {Create = function(id, _, _, fn) callbacks[id] = fn end, Simple = function() end, Remove = function() end}
  w.cvars = {AddChangeCallback = function() end}
  w.navmesh = {IsLoaded = function() return false end}
  w.ErrorNoHalt = error
  w.states = {}
  w.bgNPC = {Actor = {Helpers = {}}, Assert = {Arg = function() end},
    Table = {HasValue = table.HasValue}, Util = {}, Combat = {IsIgnored = function() return false end, IsAttacker = w.IsValid, IsFighting = function() return false end},
    Modes = {IsPeaceful = function() return false end},
    Modules = {Get = function() return {HasWanted = function() return false end} end},
    Actors = {Get = function(ent) return ent and ent.actor end, GetAll = function() return actors end},
    Vision = {HasLineOfSight = function(_, enemy) return enemy.visible ~= false end},
    States = {Register = function(name, _, def) w.states[name] = def end}}
  function w.Load(path)
    local fn = assert(CompileFile('background_npcs_core/' .. path))
    setfenv(fn, w)()
  end
  function w.Entity(x)
    local ent = {valid = true, health = 100, pos = Vector(x or 0, 0, 0)}
    function ent:Health() return self.health end
    function ent:GetMaxHealth() return 100 end
    function ent:GetPos() return self.pos end
    function ent:IsPlayer() return false end
    function ent:IsNPC() return true end
    function ent:IsNextBot() return false end
    function ent:IsVehicle() return false end
    function ent:GetForward() return Vector(1, 0, 0) end
    return ent
  end
  w.Load('actor/components/sh_enemies.lua')
  function w.Actor()
    local a = setmetatable({npc = w.Entity(), enemies = {}, enemies_count = 0, enemies_always_visible = {},
      mechanics = {enemies_controller = true}, state = 'defense', state_data = {}, data = {}, weapon = 'weapon_pistol', walkPath = {}}, {__index = w.bgNPC.Actor})
    a.npc.actor = a
    function a:GetNPC() return self.npc end
    function a:GetPos() return self.npc:GetPos() end
    function a:IsAlive() return self.npc.valid and self.npc.health > 0 end
    function a:GetState() return self.state end
    function a:GetStateData() return self.state_data end
    function a:HasState(state) return istable(state) and table.HasValue(state, self.state) or state == self.state end
    function a:HasTeam(other) return not isstring(other) and other ~= nil and other.npc ~= nil end
    function a:InVehicle() return false end
    function a:IsCivilian() return false end
    function a:IsWanted() return false end
    function a:IsMeleeWeapon() return false end
    function a:PrepareWeapon() end
    function a:Voice() end
    function a:WalkDestinationExists() return false end
    function a:StopWalk() self.walkPath = {} end
    function a:WalkToPos(pos) self.destination = pos end
    function a:WalkToTarget(target) self.followed = target end
    function a:SetState(state) self.state = state end
    function a:GetBody() return self.body end
    a.body = {away = 0}
    function a.body:IsValid() return true end
    function a.body:GetEnemy() return self.enemy end
    function a.body:SetEnemy(enemy, pos) self.enemy, self.memory = enemy, pos end
    function a.body:GetEnemyLastTimeSeen() return 0 end
    function a.body:SetDisposition() end
    function a.body:SetAlertLevel() end
    function a.body:IsMoving() return false end
    function a.body:StopMoving() self.stopped = true end
    function a.body:MoveAwayFromEnemy() self.away = self.away + 1 end
    function a.body:MoveTo(pos) a.destination = pos end
    actors[#actors + 1] = a
    return a
  end
  w.callbacks = callbacks
  return w
end

bgNPC.Test.Add('pursuit.stable_target_and_perception', function(check)
  local w = World()
  local actor, near, far = w.Actor(), w.Entity(100), w.Entity(200)
  actor:AddEnemy(near) actor:AddEnemy(far)
  check(actor:GetEnemy() == near, 'initial target is the nearest living enemy')
  far.pos = Vector(10, 0, 0)
  check(actor:GetEnemy() == near, 'a distance change does not steal the active target')
  actor.last_attacker, actor.last_attacked_at = far, w.now
  actor.squad = {enemy = near}
  check(actor:GetEnemy() == far, 'an immediate attacker takes priority over the formation target')
  w.now = 106
  check(actor:GetEnemy() == near, 'the group target resumes after the immediate attack window')
  near.visible, far.visible = false, true
  actor.enemy_last_position = nil
  actor:EnemiesRecalculate()
  check(actor.body.enemy == near, 'the body and planner keep the same selected enemy without LOS')
  check(not actor.enemy_last_position[near] and actor.enemy_last_position[far] == far.pos, 'all visible known enemies are observed, even with a nearer hidden enemy')
  local remembered = Vector(actor.enemy_last_position[far])
  far.visible, far.pos = false, Vector(300, 0, 0)
  w.now = 107
  actor:EnemiesRecalculate()
  check(actor.enemy_last_position[far] == remembered, 'hidden movement does not update enemy memory')
  local ally = w.Actor()
  ally:AddEnemy(far)
  check(ally:ShareEnemyMemory(actor, far) and ally.enemy_last_seen[far] == 106, 'a reported enemy receives the original observation time, not a fresh timestamp')
  check(ally.enemy_last_position[far] == remembered, 'allied memory contains the observed position, not the live hidden position')
  w.now = 200
  check(not ally:ShareEnemyMemory(actor, far), 'stale observations are not forwarded')
  near.health = 0
  check(actor:GetEnemy() == far, 'a dead target is replaced')
  actor:RemoveEnemy(far)
  check(actor:GetEnemy() == NULL, 'no dead or removed enemy remains selected')
  check(bgNPC.NextBotBody.GetEnemyLastTimeSeen({ent = NULL, enemy_seen = 100}, NULL) == 0,
    'script reload discards the old global NextBot sighting timestamp')
end)

bgNPC.Test.Add('pursuit.combat_radius', function(check)
  local w = World()
  w.Load('api/sv_combat.lua')
  local actor, first, second = w.Actor(), w.Entity(1000), w.Entity(1500)
  actor:AddEnemy(first) actor:AddEnemy(second)
  check(w.bgNPC.Combat.IsInCombatRadius(actor), 'the radius boundary is protected')
  first.pos = Vector(1000.1, 0, 0)
  check(not w.bgNPC.Combat.IsInCombatRadius(actor), 'leaving every enemy radius releases the protection')
  second.pos = Vector(500, 0, 0)
  check(w.bgNPC.Combat.IsInCombatRadius(actor), 'any nearby enemy protects the actor, not only its selected target')
  second.health = 0
  check(not w.bgNPC.Combat.IsInCombatRadius(actor), 'dead enemies do not prevent cleanup')
  first.pos, actor.state = Vector(100, 0, 0), 'siege'
  check(w.bgNPC.Combat.IsInCombatRadius(actor), 'quiet siege waiting is still combat')
  actor.state = 'walk'
  check(not w.bgNPC.Combat.IsInCombatRadius(actor), 'a calm actor with a stale list is not permanently protected')
end)

bgNPC.Test.Add('pursuit.hidden_enemy_approach', function(check)
  local w = World()
  w.Load('brain/fsm/states/sv_defense.lua')
  w.Load('brain/fsm/states/sv_take_cover.lua')
  local actor, enemy = w.Actor(), w.Entity(300)
  actor:AddEnemy(enemy)
  local known = Vector(200, 0, 0)
  actor.enemy_last_position = {[enemy] = known}
  enemy.visible, enemy.pos = false, Vector(600, 0, 0)
  w.states.defense.update(actor)
  check(actor.destination == known and not actor.followed and actor.body.away == 0, 'a nearby hidden target is pursued at its last observed position without retreating or tracking through walls')
  check(w.states.take_cover.pre_start(actor, nil, {}) == 'defense', 'a hidden enemy cannot start another cover action')
  actor.state = 'take_cover'
  w.states.take_cover.update(actor, nil, {})
  check(actor.state == 'defense', 'losing sight ends an existing cover pause')
end)

bgNPC.Test.Add('pursuit.hidden_group_approach', function(check)
  local w = World()
  local leader, member, enemy = w.Actor(), w.Actor(), w.Entity(-200)
  leader:AddEnemy(enemy) member:AddEnemy(enemy)
  local known = Vector(enemy.pos)
  leader.enemy_last_position, leader.enemy_last_seen = {[enemy] = known}, {[enemy] = w.now}
  member.enemy_last_position, member.enemy_last_seen = nil, nil
  enemy.visible, enemy.pos = false, Vector(-900, 0, 0)
  w.Load('systems/sv_tactical_groups.lua')
  w.callbacks.BGN_TacticalGroupUpdate()
  check(leader.squad and leader.squad.squad.formation == 'column', 'a hidden target uses a pursuit column')
  check(leader.squad and leader.squad.slot == known, 'the column approaches the known position without a 550-unit standoff')
  check(member.enemy_last_position[enemy] == known, 'the group passes its observed position to a member that never saw the target')
  check(member:GetEnemy() == enemy and leader:GetEnemy() == enemy, 'group motion, body selection and planning resolve the same enemy')
end)

bgNPC.Test.Add('pursuit.wanted_target_is_known', function(check)
  local w = World()
  local actor, target = w.Actor(), w.Entity(900)
  target.visible = false
  w.bgNPC.Modules.Get = function() return {HasWanted = function(_, ent) return ent == target end} end
  actor:AddEnemy(target)
  check(actor.enemy_last_position and actor.enemy_last_position[target] == target.pos, 'a wanted target out of sight is still a known position')
  local other = w.Entity(950)
  other.visible = false
  actor:AddEnemy(other)
  check(not actor.enemy_last_position[other], 'an unseen non-wanted enemy has no known position')
end)
