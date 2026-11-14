-- Opt-in native fixture. Send through a temporary SERVER bridge in an isolated single-player session.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved', 'use isolated gm_bigcity_improved')
assert(not BGNSiegeLabTest, 'siege fixture already running')
local ply = player.GetHumans()[1]
local room = Vector(-748.617798, -4298.178223, -11135.968750)
local doors = {}
for _, door in ipairs(ents.FindInSphere(room, 350)) do
  if bgNPC.Util.IsDoor(door) then doors[#doors + 1] = door end
end
assert(#doors == 2, 'the specified test room needs its two original door leaves')
local saved = {pos = ply:GetPos(), ang = ply:EyeAngles(), move = ply:GetMoveType(), health = ply:Health(),
  god = ply:HasGodMode(), rifle = ply:HasWeapon('weapon_ar2')}
local tasks, actors, entities = {}, {}, {}
for _, id in ipairs({'bgn_actors_spawner_process', 'bgn_zone_actors_spawner_process', 'bgn_actors_remover_process', 'bgn_scenic'}) do
  local task = bgNPC.Tasks.list[id]
  if task then tasks[id] = task.func bgNPC.Tasks.Remove(id) end
end
local report = {map = game.GetMap(), cases = {}, errors = {}}
BGNSiegeLabTest = report
local cases = {{'npc', 'npc_metropolice'}, {'nextbot', 'npc_metropolice'}, {'nextbot', 'npc_combine_s'}, {'npc', 'npc_combine_s', 'player'},
  {'npc', 'npc_metropolice', nil, 'exit'}, {'nextbot', 'npc_combine_s', nil, 'damage'}}
local index, current = 0
local Finish, Next
local function Write()
  file.CreateDir('bgn_siege_lab')
  file.Write('bgn_siege_lab/verification.json', util.TableToJSON(report, true))
end
local function Clear()
  if current and current.entry and not current.entry.finished then bgNPC.Siege.Finish(current.entry) end
  for _, ent in ipairs(entities) do if IsValid(ent) then ent:Remove() end end
  for _, actor in ipairs(actors) do actor:Remove() end
  actors, entities = {}, {}
end
Finish = function()
  Clear()
  timer.Remove('BGN_SiegeLabTest')
  hook.Remove('OnEntityCreated', 'BGN_SiegeLabTest')
  hook.Remove('EntityFireBullets', 'BGN_SiegeLabTest')
  hook.Remove('PostEntityTakeDamage', 'BGN_SiegeLabTest')
  for id, fn in pairs(tasks) do bgNPC.Tasks.Add(id, fn) end
  ply:SetMoveType(saved.move) ply:SetPos(saved.pos) ply:SetEyeAngles(saved.ang) ply:SetHealth(saved.health)
  if not saved.god then ply:GodDisable() end
  if not saved.rifle then ply:StripWeapon('weapon_ar2') end
  for _, door in ipairs(doors) do if IsValid(door) then door:Fire('Close') end end
  report.done, report.passed = true, #report.errors == 0
  Write()
  BGNSiegeLabTest = nil
end
local function Protect(fn)
  if not BGNSiegeLabTest then return false end
  local ok, err = xpcall(fn, debug.traceback)
  if not ok then
    report.errors[#report.errors + 1] = err
    if current then
      report.failure = {name = current.name, created = current.created, phases = current.phases,
        phase = current.entry and current.entry.phase, used = current.entry and current.entry.used,
        operator_pos = IsValid(current.operator:GetNPC()) and tostring(current.operator:GetPos()),
        door_a = IsValid(doors[1]) and doors[1]:GetInternalVariable('m_eDoorState'),
        door_b = IsValid(doors[2]) and doors[2]:GetInternalVariable('m_eDoorState')}
      report.failure.members = {}
      for actor, member in pairs(current.entry and current.entry.members or {}) do
        report.failure.members[#report.failure.members + 1] = {pos = tostring(actor:GetPos()), slot = tostring(member.slot),
          distance = actor:GetPos():Distance(member.slot), near = member.near}
      end
    end
    Finish()
  end
  return ok
end
local function Check(value, message) assert(value, message) end

hook.Add('OnEntityCreated', 'BGN_SiegeLabTest', function(ent)
  timer.Simple(0, function()
    if not current or not current.entry or not IsValid(ent) then return end
    local class = ent:GetClass()
    if (class == 'npc_grenade_frag' or class == 'npc_manhack') and current.entry.phase == 'payload'
      and ent:GetPos():DistToSqr(current.entry.portal.center) < 600 ^ 2 then
      current.created = current.created + 1
      entities[#entities + 1] = ent
    end
  end)
end)
hook.Add('EntityFireBullets', 'BGN_SiegeLabTest', function(ent)
  local actor = bgNPC.Actors.Get(ent)
  if current and actor and actor.siege and actor.siege.phase == 'wait' then current.shots = current.shots + 1 end
end)
hook.Add('PostEntityTakeDamage', 'BGN_SiegeLabTest', function(target, damage, took)
  if current and target == current.target and took and damage:GetInflictor().bgn_siege_owner then
    current.damage = current.damage + damage:GetDamage()
    current.attributed = damage:GetAttacker() == current.operator:GetNPC()
  end
end)

local function Spawn(body, class, pos)
  local npc = ents.Create(body == 'nextbot' and 'bgn_nextbot' or class)
  npc.bgn_npc_class = class
  npc:SetPos(pos) npc:SetAngles(Angle(0, -90, 0)) npc:Spawn() npc:Activate()
  local actor = bgNPC.Actor.Create(npc, 'police')
  actors[#actors + 1] = actor
  actor.skip_auto_carry, actor.eternal = true, true
  actor.data.start_random_state, actor.data.start_state, actor.data.at_random, actor.data.regeneration = false, nil, nil, false
  actor.mechanics.use_vehicle, actor.mechanics.call_for_help, actor.mechanics.targets_controller = false, false, false
  actor.brain, actor.start_think = bgNPC.FSMBrain(actor), false
  return actor
end

Next = function()
  Clear()
  current = nil
  index = index + 1
  local spec = cases[index]
  if not spec then Finish() return end
  ply:GodEnable() ply:Give('weapon_ar2')
  bgNPC.Modules.Get('player_arrest'):RemoveTarget(ply)
  local target = ply
  if spec[3] ~= 'player' then
    target = ents.Create('npc_citizen')
    target:SetPos(room) target:Spawn() target:Activate() target:SetMaxHealth(1000) target:SetHealth(1000)
    target:SetNPCState(NPC_STATE_SCRIPT) target:SetSchedule(SCHED_NPC_FREEZE)
    entities[#entities + 1] = target
    ply:SetMoveType(MOVETYPE_NOCLIP) ply:SetPos(Vector(-1050, -3850, -11000))
    ply:SetEyeAngles(Angle(15, -50, 0))
  else
    ply:SetMoveType(MOVETYPE_WALK) ply:SetPos(room) ply:SetEyeAngles(Angle(7.084, 74.06105, 0))
  end
  for _, door in ipairs(doors) do door:Fire('Close') end
  for i = 1, 8 do
    Spawn(i == 1 and spec[1] or 'npc', i == 1 and spec[2] or 'npc_combine_s',
      Vector(-704 + (i % 2 == 0 and 110 or -110), -3820 + math.floor((i - 1) / 2) * 120, -11130))
  end
  current = {name = spec[1] .. '_' .. spec[2] .. (spec[4] and '_' .. spec[4] or ''), guard = spec[4], target = target, operator = actors[1], created = 0, shots = 0,
    damage = 0, started = CurTime(), phases = {}, until_time = CurTime() + 52}
  timer.Simple(0.7, function() Protect(function()
    for _, actor in ipairs(actors) do
      actor:RemoveAllTargets() actor:AddEnemy(target, 'defense', true)
      actor.enemy_last_seen, actor.enemy_last_position = {[target] = CurTime()}, {[target] = target:GetPos()}
      actor:SetState('defense', nil, true)
      actor:PlayStaticSequence(bgNPC.Siege.Sequence(actor, {'CombatIdle1', 'pistolangryidle2', 'Idle1'}), true)
      actor.start_think = false
    end
    timer.Simple(1.2, function() Protect(function()
      local actor = actors[1]
      current.capabilities = actor:GetNPC():IsNPC() and actor:GetNPC():CapabilitiesGet()
      local candidate = bgNPC.Siege.CanStart(actor, target)
      Check(candidate and #candidate.doors == 2 and candidate.pocket[bgNPC.Siege.Area(target:GetPos()):GetID()], 'the specified room has one double-leaf exit')
      local old_model = actor:GetNPC():GetModel()
      actor:GetNPC():SetModel('models/humans/group01/male_07.mdl')
      Check(bgNPC.Siege.CanStart(actor, target) == nil, 'a model without the required equipment animation cannot start')
      actor:GetNPC():SetModel(old_model)
      if actor:GetNPC().IsBGNNextBot then actor:GetNPC():BGN_ResetHull() end
      for _, member in ipairs(actors) do member.start_think = true end
      actor.brain = bgNPC.GOAPBrain(actor)
      actor.brain:Update()
      current.entry = actor.siege
      Check(current.entry and current.entry.operator == actor, 'GOAP starts the coordinated tactic')
    end) end)
  end) end)
  timer.Create('BGN_SiegeLabTest', 0.1, 0, function() Protect(function()
    local c, entry = current, current.entry
    Check(CurTime() < c.until_time, c.name .. ': timeout')
    if not entry then return end
    if not c.phases[entry.phase] then c.phases[entry.phase] = CurTime() end
    if entry.phase == 'wait' then
      local near, rear = 0, 0
      for actor, member in pairs(entry.members) do
        if member.near then near = near + 1 else
          rear = rear + 1
          Check(actor:GetPos():Distance(entry.portal.center) >= 616, 'other groups stay at least 650 units away, within arrival tolerance')
        end
      end
      Check(near <= 5 and rear >= 3, 'only one group is near the entrance')
      c.near, c.rear = near, rear
      if c.guard and not c.interrupted and CurTime() - c.phases.wait > 1 then
        c.interrupted = true
        if c.guard == 'exit' then
          for participant in pairs(entry.members) do participant:SetStateDelay(30) end
          c.target:SetPos(Vector(-704, -3800, -11135))
        else c.operator:GetNPC():TakeDamage(1, game.GetWorld(), game.GetWorld()) end
      end
    end
    if IsValid(entry.payload) then
      c.payload_class = entry.payload:GetClass()
      if (entry.payload:GetPos() - entry.portal.center):Dot(entry.portal.normal) < -24 then c.entered = true end
    end
    if entry.finished then
      if c.guard then
        Check(c.interrupted and not entry.used and c.created == 0, c.name .. ': interruption cancels without deploying a weapon')
      else
        Check(entry.used and c.created == 1, c.name .. ': exactly one special weapon is created')
        Check(c.entered and c.phases.hold, c.name .. ': the weapon actually enters the room')
        if not c.target:IsPlayer() then Check(c.damage > 0 and c.attributed, c.name .. ': the deployed weapon damages the target on behalf of its operator') end
        Check(c.phases.door and c.phases.door - c.phases.wait >= 11.8, 'the group waits before opening the door')
      end
      Check(c.shots == 0, c.name .. ': nobody fires during the silent wait')
      for participant in pairs(entry.members) do
        Check(not participant.siege and not participant:HasState('siege') and not participant:IsAnimationPlayed(),
          'all participants leave the tactic and release their animation, including through state delays')
      end
      if c.capabilities then Check(bit.band(c.operator:GetNPC():CapabilitiesGet(), c.capabilities) == c.capabilities, 'NPC capabilities are restored') end
      c.kick, c.used, c.passed = entry.kick, entry.used, true
      c.entry, c.operator, c.target, c.capabilities = nil, nil, nil, nil
      report.cases[#report.cases + 1] = c
      Write()
      timer.Remove('BGN_SiegeLabTest')
      timer.Simple(1, function() Protect(Next) end)
    end
  end) end)
end

Protect(Next)
return 'Started siege checks; results: data/bgn_siege_lab/verification.json'
