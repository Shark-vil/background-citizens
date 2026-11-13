local PATH = 'background_npcs/lethal_weapons.json'
local Actors, Combat = bgNPC.Actors, bgNPC.Combat
local enabled = GetConVar('bgn_react_to_lethal_weapon')
-- Keep the cache through script reloads; gameplay checks never read DATA.
if not bgNPC.lethal_weapons then
  local raw = file.Read(PATH, 'DATA')
  local classes = {}
  if raw then classes = util.JSONToTable(raw) end
  local valid = istable(classes)
  if valid then
    for class, value in pairs(classes) do
      if not isstring(class) or class == '' or value ~= true then valid = false break end
    end
  end
  bgNPC.lethal_weapons = {classes = valid and classes or {}, writable = valid}
  if not valid then ErrorNoHalt('[Background NPCs] Invalid ' .. PATH .. '; preserved without overwriting.\n') end
end
local cache = bgNPC.lethal_weapons

local function WeaponClass(ent)
  if not IsValid(ent) or not isfunction(ent.GetActiveWeapon) then return end
  local weapon = ent:GetActiveWeapon()
  if IsValid(weapon) then return weapon:GetClass() end
end

hook.Add('EntityTakeDamage', 'BGN_LethalWeaponDamage', function(target, dmg)
  local actor = Actors.Get(target)
  if not actor then return end
  local attacker, inflictor = dmg:GetAttacker(), dmg:GetInflictor()
  actor.lethal_weapon_damage = {
    attacker = attacker,
    excluded = dmg:IsExplosionDamage() or dmg:IsDamageType(DMG_VEHICLE)
      or (IsValid(inflictor) and inflictor:IsVehicle())
      or (IsValid(attacker) and attacker:IsPlayer() and attacker:InVehicle()),
  }
end)

hook.Add('BGN_OnKilledActor', 'BGN_LearnLethalWeapon', function(actor, attacker)
  local damage = actor.lethal_weapon_damage
  if not damage or damage.attacker ~= attacker or damage.excluded then return end
  if IsValid(attacker) and attacker:IsPlayer() and attacker:InVehicle() then return end
  local class = WeaponClass(attacker)
  if not isstring(class) or class == '' or cache.classes[class] then return end
  cache.classes[class] = true
  if cache.writable and not file.Write(PATH, util.TableToJSON(cache.classes, true)) then
    ErrorNoHalt('[Background NPCs] Failed to write ' .. PATH .. '.\n')
  end
end)

local function React(actor, target)
  if not actor:IsAlive() or not (actor:HasTeam('residents') or actor:HasTeam('police')) then return end
  local npc = actor:GetNPC()
  if npc == target or actor:HasEnemy(target) or actor:HasTeam(target) then return end
  if npc:GetPos():DistToSqr(target:GetPos()) > 800 ^ 2 or not Combat.CanWitness(actor, target, true) then return end
  local reaction = actor:GetReactionForDamage(target)
  if reaction == 'ignore' or reaction == 'none' then return end
  actor:AddEnemy(target, reaction)
  -- AddEnemy can be refused by arrest, medic or addon hooks.
  if not actor:HasEnemy(target) then return end
  actor:SetReaction(reaction)
  if actor:EqualStateGroup('calm') then
    actor:RemoveAllTargets()
    actor:SetState(reaction)
  end
end

timer.Create('BGN_ReactToLethalWeapon', 1, 0, function()
  if not enabled:GetBool() or bgNPC.Modes.IsPeaceful() then return end
  local observers = {}
  for i, actor in ipairs(Actors.GetAll()) do observers[i] = actor end
  for _, target in ipairs(ents.GetAll()) do
    if Combat.IsAttacker(target) and target:Health() > 0 and not Combat.IsIgnored(target)
      and not (target:IsPlayer() and bgNPC.Modes.IsFriend()) then
      local class = WeaponClass(target)
      if class and cache.classes[class] then
        for _, actor in ipairs(observers) do React(actor, target) end
      end
    end
  end
end)
