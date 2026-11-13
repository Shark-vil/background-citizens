-- Only vehicle collisions can remove a civilian's residents team.
local POLICE_RAM_TIME, POLICE_RAM_GAP = 3, 3
local RAM_REACTION_CHANCE = 10
function bgNPC.OffenderFromRamming(attacker, damage, police_target)
  local offender = bgNPC.Actors.Get(attacker)
  if bgNPC.Modes.IsPeaceful() or not offender or not offender:IsAlive() or not offender:IsCivilian() or offender:HasTeam('medics') or not offender:InVehicle() or not damage or damage:GetDamage() <= 0 or not (damage:IsDamageType(DMG_CRUSH) or damage:IsDamageType(DMG_VEHICLE)) then return false end
  local car = offender:GetVehicle()
  if not IsValid(car) or (damage:GetAttacker() ~= car and damage:GetInflictor() ~= car) then return false end
  if police_target then
    local now, ram = CurTime(), offender.police_ram
    if not ram or ram.target ~= police_target or now - ram.last > POLICE_RAM_GAP then
      ram = {
        target = police_target,
        since = now
      }

      offender.police_ram = ram
    end

    ram.last = now
    if now - ram.since < POLICE_RAM_TIME or not bgNPC.Util.Chance(RAM_REACTION_CHANCE) then return false end
  end

  local team = {}
  for _, name in ipairs(offender.data.team or {}) do
    if name ~= 'residents' then team[#team + 1] = name end
  end

  team[#team + 1] = 'offenders'
  offender:SetTeam(team)
  return true
end