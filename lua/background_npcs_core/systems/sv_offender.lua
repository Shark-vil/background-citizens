--[[
	Offender: a civilian who kills a resident or an officer stops being a resident. Only this actor's team changes
	(actor.data is a copy of the config), so the team immunity no longer covers him: the police and the residents
	treat him as an enemy (wanted list, arrest, defense, fear). He runs from them or, near an officer, may surrender.
--]]
local TEAM = 'offenders'
local SURRENDER_CHANCE = 40
local SURRENDER_HEALTH_FRACTION = 0.5 -- a healthy offender never gives up
local FLEE_RADIUS = 1500
local WantedModule = bgNPC.Modules.Get('wanted')
local ArrestModule = bgNPC.Modules.Get('player_arrest')
local function MakeOffender(actor)
  local team = {}
  for _, name in ipairs(actor.data.team or {}) do
    if name ~= 'residents' then team[#team + 1] = name end
  end

  team[#team + 1] = TEAM
  actor:SetTeam(team)
end

local function RunAway(offender)
  local npc = offender:GetNPC()
  local nearest, nearest_dist
  for _, actor in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), FLEE_RADIUS)) do
    if actor ~= offender and actor:IsAlive() and actor:HasTeam('residents') then
      local dist = actor:GetNPC():GetPos():DistToSqr(npc:GetPos())
      if not nearest_dist or dist < nearest_dist then nearest, nearest_dist = actor, dist end
    end
  end

  if not nearest then return end
  offender:RemoveAllTargets()
  offender:AddEnemy(nearest:GetNPC(), 'fear')
  offender:SetState('fear', nil, true)
end

-- A civilian driver who rams an officer's car: no longer a teammate of the police, who then react to the hit as to an attack.
function bgNPC.OffenderFromRamming(attacker)
  local offender = bgNPC.Actors.Get(attacker)
  if not offender or not offender:IsAlive() or not offender:IsCivilian() or offender:HasTeam('medics') then return end
  MakeOffender(offender)
  if GetConVar('bgn_enable_wanted_mode'):GetBool() and not bgNPC.Modes.IsPeaceful() then WantedModule:AddWanted(attacker) end
end

-- Medics are untouchable for the police: never an enemy, whatever team the medic ends up with.
hook.Add('BGN_AddActorEnemy', 'BGN_MedicsImmuneToPolice', function(actor, ent)
  local target = bgNPC.Actors.Get(ent)
  if target and target:HasTeam('medics') and actor:HasTeam('police') then return true end
end)

hook.Add('BGN_OnKilledActor', 'BGN_Offender', function(victim, attacker)
  if bgNPC.Modes.IsPeaceful() or not IsValid(attacker) or attacker == victim:GetNPC() then return end
  local offender = bgNPC.Actors.Get(attacker)
  if not offender or not offender:IsAlive() or not offender:IsCivilian() or offender:HasTeam('medics') or not victim:HasTeam('residents') then return end
  MakeOffender(offender)
  -- nobody saw it: no manhunt, but the immunity is gone
  if not GetConVar('bgn_enable_wanted_mode'):GetBool() or not bgNPC.Vision.AnyActorSees(attacker, victim) then return end
  WantedModule:AddWanted(attacker)
  local police = ArrestModule:FoundPoliceInRadius(attacker)
  local hurt = attacker:Health() < attacker:GetMaxHealth() * SURRENDER_HEALTH_FRACTION
  if police and hurt and GetConVar('bgn_arrest_mode'):GetBool() and bgNPC.Util.Chance(SURRENDER_CHANCE) and ArrestModule:Surrender(offender, police) then return end
  RunAway(offender)
end)
