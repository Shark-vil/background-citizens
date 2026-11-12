local Assert = bgNPC.Assert
local Util = bgNPC.Util
local Actors = bgNPC.Actors
local Modules = bgNPC.Modules
local Combat = bgNPC.Combat
--
local FirstAttackerModule, WantedModule
local POLICE_ATTACK_WINDOW = 10
local function HasRangedWeapon(enemy)
  local weapon = enemy.GetActiveWeapon and enemy:GetActiveWeapon()
  if not IsValid(weapon) or weapon.bgn_carried_item then return false end
  local class = weapon:GetClass()
  if bgNPC.Table.HasValue(bgNPC.cfg.melee_weapons, class) then return false end
  for safe in GetConVar('bgn_arrest_safe_weapons'):GetString():gmatch('[^,%s]+') do
    if class == safe then return false end
  end
  return true
end

-- A player in a vehicle, or an actor seated in a car (a baton cannot reach it)
local function IsInVehicle(enemy)
  if enemy:IsPlayer() then return enemy:InVehicle() end
  if enemy:IsVehicle() then return true end
  local actor = Actors.Get(enemy)
  return actor ~= nil and actor:InVehicle()
end

function Combat.CanPoliceShoot(enemy)
  if not IsValid(enemy) then return false end
  return (HasRangedWeapon(enemy) or enemy.bgn_has_killed or bgNPC.Statistics.GetSum(enemy) >= 1) and enemy.bgn_last_attack ~= nil and CurTime() - enemy.bgn_last_attack < POLICE_ATTACK_WINDOW and not Modules.Get('player_arrest'):IsProtected(enemy)
end

local function RecordKill(victim, attacker)
  attacker = Combat.ResolveVehicleAttacker(attacker)
  -- Wanted statistics reset on escalation; that must not erase the first kill for weapon selection.
  if IsValid(attacker) and attacker ~= victim then attacker.bgn_has_killed = true end
end

hook.Add('OnNPCKilled', 'BGN_PoliceLethalThreat', RecordKill)
hook.Add('BGN_OnKilledActor', 'BGN_PoliceLethalThreat', function(actor, attacker) RecordKill(actor:GetNPC(), attacker) end)
hook.Add('PlayerDeath', 'BGN_PoliceLethalThreat', function(victim, _, attacker)
  victim.bgn_has_killed = nil
  victim.bgn_last_attack = nil
  RecordKill(victim, attacker)
end)

-- Is the entity in a real fight: it shot or hurt someone lately, or an actor shoots back at an enemy.
local FIGHT_WINDOW = 10
local FIGHT_STATES = {'defense', 'killer', 'take_cover', 'retreat'}
function Combat.IsFighting(ent)
  if not IsValid(ent) then return false end
  if CurTime() - (ent.bgn_last_attack or -FIGHT_WINDOW) < FIGHT_WINDOW then return true end
  local actor = Actors.Get(ent)
  return actor ~= nil and actor:EnemiesCount() > 0 and actor:HasState(FIGHT_STATES)
end

hook.Add('EntityTakeDamage', 'BGN_LastAttackOnDamage', function(_, dmginfo)
  local attacker = Combat.ResolveVehicleAttacker(dmginfo:GetAttacker())
  if dmginfo:GetDamage() > 0 and Combat.IsAttacker(attacker) then attacker.bgn_last_attack = CurTime() end
end)

hook.Add('EntityFireBullets', 'BGN_PoliceLastAttack', function(shooter)
  shooter = Combat.ResolveVehicleAttacker(shooter)
  if IsValid(shooter) and (shooter:IsPlayer() or shooter:IsNPC() or shooter:IsNextBot()) then shooter.bgn_last_attack = CurTime() end
end)

local function GetFirstAttackerModule()
  FirstAttackerModule = FirstAttackerModule or Modules.Get('first_attacker')
  return FirstAttackerModule
end

local function GetWantedModule()
  WantedModule = WantedModule or Modules.Get('wanted')
  return WantedModule
end

-- ---------------------------------------------------------------------------
-- Weapons
-- ---------------------------------------------------------------------------
-- VJ Base NPCs define their own weapon list, prefer it over the actor config.
local function GetVJBaseWeapon(npc)
  local vj_npcs = list.GetForEdit('VJBASE_SPAWNABLE_NPC')
  local vj_data = vj_npcs and vj_npcs[npc:GetClass()]
  if vj_data and istable(vj_data.Weapons) and #vj_data.Weapons ~= 0 then return bgNPC.Table.Random(vj_data.Weapons) end
end

-- Gives the weapon if the NPC doesn't have it and makes it active.
-- @return boolean true if the weapon is in the NPC's hands
local function EquipWeapon(actor, npc, weapon_class)
  local weapon = npc:GetWeapon(weapon_class)
  if not IsValid(weapon) then
    if hook.Run('BGN_PreGiveWeapon', actor, npc, weapon_class) then return false end
    weapon = npc:Give(weapon_class)
    hook.Run('BGN_PostGiveWeapon', actor, npc, weapon_class)
    if not IsValid(weapon) then return false end
  end

  local active_weapon = npc:GetActiveWeapon()
  if active_weapon == weapon then return true end
  if hook.Run('BGN_PreSelectWeapon', actor, npc, weapon_class) then return false end
  npc:SelectWeapon(weapon_class)
  hook.Run('BGN_PostSelectWeapon', actor, npc, weapon_class)
  -- A police actor with the stunstick (idle state) and the pistol shows both in its hands: keep only the selected one.
  -- By team, not by NPC class: the config may give the police another class.
  if actor:HasTeam('police') and npc.GetWeapons then
    for _, other in ipairs(npc:GetWeapons()) do
      if other ~= weapon then other:Remove() end
    end
  end
  return true
end

-- Arms the actor.
-- @param actor table
-- @param weapon_class string|nil weapon to give, nil - the actor's own weapon
-- @param switching boolean|nil with a class: true - replace another active weapon,
--   false - only give the weapon if the NPC holds nothing else
function Combat.EquipActor(actor, weapon_class, switching)
  Assert.Arg(1, actor, 'actor', 'bgNPC.Combat.EquipActor')
  Assert.Arg(2, weapon_class, 'string|nil', 'bgNPC.Combat.EquipActor')
  Assert.Arg(3, switching, 'boolean|nil', 'bgNPC.Combat.EquipActor')
  if not actor:IsAlive() or not (actor:IsNPC() or actor:IsNextBot()) then return end
  if actor.carry_item and bgNPC.CarryItems and (weapon_class or actor.weapon) then bgNPC.CarryItems.Suspend(actor) end
  local cvar_disable_weapon = Util.GetCVar('bgn_disable_weapon_' .. actor:GetType())
  if cvar_disable_weapon and cvar_disable_weapon:GetBool() then return end
  local npc = actor:GetNPC()
  local active_weapon = npc:GetActiveWeapon()
  if not weapon_class and actor.class == 'npc_metropolice' and actor:HasTeam('police') then
    local enemy = actor:GetNearEnemy()
    if not IsValid(enemy) and actor.GetFirstTarget then enemy = actor:GetFirstTarget() end
    if IsValid(enemy) then
      local data = actor:GetStateData()
      data.police_firearm = not Combat.CanPoliceUseStunstick(actor, enemy) or IsInVehicle(enemy)
      weapon_class = data.police_firearm and actor:GetActorWeapon() or 'weapon_stunstick'
      if not weapon_class or weapon_class == 'weapon_stunstick' then
        weapon_class = data.police_firearm and 'weapon_pistol' or 'weapon_stunstick'
      end
      switching = true
    end
  end

  if weapon_class then
    if IsValid(active_weapon) then
      local is_same = active_weapon:GetClass() == weapon_class
      if is_same or not switching then return end
    end
  else
    weapon_class = actor:GetActorWeapon()
    if not weapon_class or #weapon_class == 0 then return end
    if IsValid(active_weapon) then return end
    weapon_class = GetVJBaseWeapon(npc) or weapon_class
  end

  if not EquipWeapon(actor, npc, weapon_class) then return end
  Combat.ApplyWeaponSkill(actor)
  hook.Run('BGN_OnSetActorWeapon', actor)
end

-- Sets the shooting skill (HL2 NPC or NextBot): the config weapon_skill, or poor for an actor that was spawned
-- unarmed and picked a weapon up (actor.novice_shooter).
function Combat.ApplyWeaponSkill(actor)
  local npc = actor:GetNPC()
  if not IsValid(npc) or not npc.SetCurrentWeaponProficiency then return end
  local data = actor:GetData()
  -- weaponSkill: backward compatibility with the old version of the config
  local weapon_skill = actor.novice_shooter and WEAPON_PROFICIENCY_POOR or data.weapon_skill or data.weaponSkill
  if isnumber(weapon_skill) then npc:SetCurrentWeaponProficiency(weapon_skill) end
end

-- ---------------------------------------------------------------------------
-- Enemy resolving
-- ---------------------------------------------------------------------------
-- Returns the driver when the attacker is a vehicle, nil if nobody drives it.
function Combat.ResolveVehicleAttacker(attacker)
  -- an actor's Decent Vehicle car (or its AI): the driving actor, so the team rules apply to its hits
  local provider = BGN_VEHICLE and IsValid(attacker) and BGN_VEHICLE:GetVehicleProvider(attacker)
  local driver = provider and provider:GetDriver()
  if driver and IsValid(driver:GetNPC()) then return driver:GetNPC() end
  if IsValid(attacker) and attacker:IsVehicle() then
    attacker = attacker:GetDriver()
    if not IsValid(attacker) then return end
  end
  return attacker
end

-- A player, an NPC/NextBot or an actor in a Decent Vehicle seat (its DV entity is none of the former).
function Combat.IsAttacker(ent)
  return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or Actors.Get(ent) ~= nil)
end

-- Is the attacker an enemy of the target actor or of any of its teammates.
function Combat.IsEnemyOfTeam(target_actor, attacker)
  Assert.Arg(1, target_actor, 'actor', 'bgNPC.Combat.IsEnemyOfTeam')
  if not IsValid(attacker) or attacker:Health() <= 0 then return false end
  local first_attacker = GetFirstAttackerModule()
  local attacker_actor = Actors.Get(attacker)
  if attacker_actor and attacker_actor:HasEnemy(target_actor) then return true end
  if first_attacker:IsFirstAttacker(attacker, target_actor) then return true end
  local actors = Actors.GetAll()
  for i = #actors, 1, -1 do
    local actor = actors[i]
    if actor ~= target_actor and actor:IsAlive() and actor:HasTeam(target_actor) then
      if attacker_actor and not actor:HasTeam(attacker_actor) and attacker_actor:HasEnemy(actor) then return true end
      if actor:HasEnemy(attacker) or first_attacker:IsFirstAttacker(attacker, actor:GetNPC()) then return true end
    end
  end
  return false
end

local function GetEntityType(ent)
  if not IsValid(ent) then return nil end
  if ent:IsNextBot() then return 'nextbot' end
  if ent:IsNPC() then return 'npc' end
  if ent:IsPlayer() then return 'player' end
  -- a seated actor's body is a Decent Vehicle entity, neither NPC nor NextBot
  if Actors.Get(ent) then return 'npc' end
  return nil
end

-- Decides which side of a fight (target or attacker) the actor should treat as an enemy.
-- @return entity|nil enemy, nil if the actor should stay out of it
function Combat.ResolveEnemy(actor, target, attacker)
  Assert.Arg(1, actor, 'actor', 'bgNPC.Combat.ResolveEnemy')
  local target_type = GetEntityType(target)
  local attacker_type = GetEntityType(attacker)
  if not target_type or not attacker_type then return end
  local is_attacker_team = actor:HasTeam(attacker)
  local is_target_team = actor:HasTeam(target)
  if is_attacker_team and is_target_team then return end
  if is_attacker_team then return target end
  if is_target_team then return attacker end
  local first_attacker = GetFirstAttackerModule()
  local wanted = GetWantedModule()
  local attacker_actor = Actors.Get(attacker)
  local target_actor = Actors.Get(target)
  -- A player attacks an NPC that is not an actor
  if not target_actor and target_type == 'npc' and attacker_type == 'player' then
    if target:Disposition(attacker) == D_HT then return target end
    return attacker
  end

  -- A player is attacked by an NPC that is not an actor
  if not attacker_actor and attacker_type ~= 'player' and target_type == 'player' then return attacker end
  if wanted:HasWanted(attacker) then return attacker end
  if wanted:HasWanted(target) then return target end
  -- Someone from the actor's team is already fighting the target
  if Combat.IsEnemyOfTeam(actor, target) then return target end
  -- Someone from the actor's team is already fighting the attacker
  if Combat.IsEnemyOfTeam(actor, attacker) then return attacker end
  if attacker_actor and not attacker_actor:HasEnemy(target) then return target end
  if target_actor and not target_actor:HasEnemy(attacker) then return attacker end
  if target_type == 'player' or attacker_type == 'player' then
    -- The player is attacked by the actor who was the first victim
    if first_attacker:IsFirstAttacker(target, attacker) then return target end
    -- The player is attacked by the actor who started the fight
    if first_attacker:IsFirstAttacker(attacker, target) then return attacker end
  end
end
