--[[
	Panic and threat search (cvar "bgn_threat_search", off by default).
	A calm ally who sees an actor die but not the killer does not learn the killer: a resident (not police, not a medic)
	panics and hides from where the killer stood (state "panic"), the police and gangs go there and search the area
	(state "search_threat"), walking quietly near the killer. While the state lasts the incident keeps the killer's
	weapon class: anyone holding it, not only the killer, seen HITS checks in a row within FIND_DIST in the view cone
	is taken for the killer. A killer without a weapon (or with a safe one, bgn_arrest_safe_weapons) is recognized
	only in person.
	State data: { incident = { killer, weapon, pos, expires } }.
--]]
local Actors, Combat = bgNPC.Actors, bgNPC.Combat
local enabled = GetConVar('bgn_threat_search')
local safe_weapons = GetConVar('bgn_arrest_safe_weapons')
local WITNESS_DIST_SQR = 1500 ^ 2
local VIEW_COS = math.cos(math.rad(60))
local FIND_DIST = 500
local CHECK_PERIOD = 0.33 -- HITS checks take about a second near a player (brain LOD_NEAR), slower far away
local HITS = 3
local SEARCH_TIME = 45
local QUIET_DIST_SQR = 1000 ^ 2
local GOAL_OFFSET = 200 -- the first goal: around where the killer stood
local PATROL_RADIUS = 600
local GOAL_TIME = 10
local REACH_DIST_SQR = 100 ^ 2
local PANIC_MIN, PANIC_MAX = 15, 25
local CROUCH = {'Crouch_Idle_Pistol', 'crouchidle', 'Crouch_IdleD'}
local ALERT_SOUND = 'background_npcs/threat_alert.wav'
local ALERT_VOLUME = 0.6
local ThreatSearch = {}
bgNPC.ThreatSearch = ThreatSearch -- read by tests/
-- @return string|nil class of the weapon in hand, nil for none or a safe one
function ThreatSearch.WeaponClass(ent)
  if not IsValid(ent) or not isfunction(ent.GetActiveWeapon) then return end
  if ent:IsPlayer() and ent:InVehicle() then return end -- a kill from a car: the gun in hand did not do it
  local weapon = ent:GetActiveWeapon()
  if not IsValid(weapon) then return end
  local class = weapon:GetClass()
  if string.find(',' .. safe_weapons:GetString() .. ',', ',' .. class .. ',', 1, true) then return end
  return class
end

function ThreatSearch.IsSuspect(actor, incident, ent)
  if not Combat.IsAttacker(ent) or ent:Health() <= 0 or ent == actor:GetNPC() then return false end
  if actor:HasTeam(ent) or Combat.IsIgnored(ent) or (ent:IsPlayer() and bgNPC.Modes.IsFriend()) then return false end
  if incident.weapon then return ThreatSearch.WeaponClass(ent) == incident.weapon end
  return ent == incident.killer
end

-- Counts one check: the same suspect HITS times in a row is recognized, a miss or another one starts over.
-- @return entity|nil the recognized suspect
function ThreatSearch.Count(data, suspect)
  data.hits = suspect and suspect == data.suspect and data.hits + 1 or (suspect and 1 or 0)
  data.suspect = suspect
  return data.hits >= HITS and suspect or nil
end

local function Eyes(npc)
  return npc.BGN_EyePos and npc:BGN_EyePos() or npc:EyePos()
end

-- the cone of Combat.CanWitness is a half-space; this one is narrower and holds for NextBots too
local function InView(npc, pos)
  local dir = pos - Eyes(npc)
  local length = dir:Length()
  local forward = npc.GetAimVector and npc:GetAimVector() or npc:GetForward()
  return length > 0 and forward:Dot(dir) / length >= VIEW_COS
end

local function FindSuspect(actor, incident)
  local npc = actor:GetNPC()
  local pos = npc:GetPos()
  -- the trace is the last check: only for a suspect close and in view
  for _, ent in ipairs(incident.weapon and ents.FindInSphere(pos, FIND_DIST) or {incident.killer}) do
    if IsValid(ent) and ThreatSearch.IsSuspect(actor, incident, ent) and pos:DistToSqr(ent:GetPos()) <= FIND_DIST ^ 2 and InView(npc, ent:WorldSpaceCenter()) and bgNPC.Vision.HasLineOfSight(npc, ent, 'threat_search') then return ent end
  end
end

local function Recognize(actor, data)
  local now = CurTime()
  if (data.next_check or 0) > now then return end
  data.next_check = now + CHECK_PERIOD
  return ThreatSearch.Count(data, FindSuspect(actor, data.incident))
end

local function Engage(actor, data, suspect, reaction)
  actor:AddEnemy(suspect, reaction)
  -- AddEnemy can be refused by arrest, medic or addon hooks: look again
  if not actor:HasEnemy(suspect) then
    data.hits = 0
    return false
  end

  actor:SetReaction(reaction)
  actor:SetState(reaction)
  -- only the recognized player hears it, from the actor
  if suspect:IsPlayer() then
    local filter = RecipientFilter()
    filter:AddPlayer(suspect)
    actor:GetNPC():EmitSound(ALERT_SOUND, 75, 100, ALERT_VOLUME, CHAN_AUTO, 0, 0, filter)
  end
  return true
end

-- an enemy from another system (a shot, a shared enemy) ends the state like an attack
local function ReactToEnemy(actor, fallback)
  if actor:HasNoEnemies() then return false end
  local reaction = actor:GetReactionForProtect(actor:GetNearEnemy())
  actor:SetState((reaction == 'ignore' or reaction == 'none') and fallback or reaction)
  return true
end

-- @return Vector a random route point around pos, pos itself without one
local function Goal(pos, radius)
  local points = bgNPC.Points.GetInRadius(pos, radius)
  return #points ~= 0 and points[math.random(#points)]:GetPos() or pos
end

hook.Add('BGN_OnKilledActor', 'BGN_ThreatSearch', function(victim, killer)
  if not enabled:GetBool() or bgNPC.Modes.IsPeaceful() or victim:InVehicle() then return end
  local victim_npc = victim:GetNPC()
  if not IsValid(victim_npc) or not Combat.IsAttacker(killer) or killer == victim_npc or Combat.IsIgnored(killer) then return end
  local center = victim_npc:WorldSpaceCenter()
  local incident = {
    killer = killer,
    weapon = ThreatSearch.WeaponClass(killer),
    pos = killer:GetPos(),
    expires = CurTime() + SEARCH_TIME
  }

  -- next tick: the killing damage reaches the ordinary witnesses (BGN_ConfirmedDamage) after the death,
  -- and one of them who saw the killer must not panic first and drop it at once
  timer.Simple(0, function()
    if not IsValid(killer) then return end
    for _, actor in ipairs(Actors.GetAll()) do
      local state = actor:IsCivilian() and not actor:HasTeam('medics') and 'panic' or (actor:HasTeam('police') or actor:HasTeam('bandits')) and 'search_threat'
      local npc = actor:GetNPC()
      if state and actor ~= victim and actor:IsAlive() and not actor:InVehicle() and actor:EqualStateGroup('calm') and actor:HasTeam(victim) and not actor:HasTeam(killer) and not actor:HasEnemy(killer) and npc:GetPos():DistToSqr(center) <= WITNESS_DIST_SQR then
        -- no view cone: from the victim to the witness, the body may already be gone or ragdolled
        local saw_death = not util.TraceLine({
          start = center,
          endpos = Eyes(npc),
          mask = MASK_BLOCKLOS,
          filter = {npc, IsValid(victim_npc) and victim_npc or nil}
        }).Hit

        -- one who sees the killer too is left to the ordinary witness reactions
        if saw_death and not Combat.CanWitness(actor, killer, true) then
          actor:SetState(state, {
            incident = incident
          })
        end
      end
    end
  end)
end)

bgNPC.States.Register('panic', 'danger', {
  start = function(actor, _, data)
    local from = data.incident.pos
    data.cover = bgNPC.FindCover(actor, from) or actor:GetDistantPointToPoint(from, math.random(700, 1000))
    data.leave = CurTime() + math.random(PANIC_MIN, PANIC_MAX)
    actor:FearScream()
  end,
  stop = function(actor) actor:StopStaticSequence() end,
  update = function(actor, _, data)
    if ReactToEnemy(actor, 'run_from_danger') then return end
    if data.leave < CurTime() then
      actor:RandomState()
      return
    end

    local suspect = Recognize(actor, data)
    if suspect and Engage(actor, data, suspect, 'run_from_danger') then return end
    if data.cover and actor:GetPos():DistToSqr(data.cover) > REACH_DIST_SQR then
      bgNPC.MoveToPoint(actor, data, data.cover, true)
    elseif not actor:IsAnimationPlayed() then
      actor:StopWalk()
      actor:GetBody():StopMoving()
      for _, name in ipairs(CROUCH) do
        if actor:IsValidSequence(name) then
          actor:PlayStaticSequence(name, true)
          break
        end
      end
    end
  end,
})

bgNPC.States.Register('search_threat', 'danger', {
  start = function(actor, _, data)
    data.goal = Goal(data.incident.pos, GOAL_OFFSET)
    data.next_goal = CurTime() + GOAL_TIME
  end,
  update = function(actor, _, data)
    if ReactToEnemy(actor, 'defense') then return end
    local incident = data.incident
    local killer = incident.killer
    if incident.expires < CurTime() or not IsValid(killer) or killer:Health() <= 0 then
      actor:RandomState()
      return
    end

    local suspect = Recognize(actor, data)
    if suspect then
      local reaction = actor:GetReactionForDamage(suspect)
      if Engage(actor, data, suspect, (reaction == 'ignore' or reaction == 'none') and 'defense' or reaction) then return end
    end

    -- also on a timer: an unreachable goal must not hold the searcher in place
    if actor:GetPos():DistToSqr(data.goal) <= REACH_DIST_SQR or (data.next_goal or 0) < CurTime() then
      data.goal = Goal(incident.pos, PATROL_RADIUS)
      data.next_goal = CurTime() + GOAL_TIME
    end

    local quiet = actor:GetPos():DistToSqr(killer:GetPos()) < QUIET_DIST_SQR
    bgNPC.MoveToPoint(actor, data, data.goal, not quiet)
    -- WalkToPos keeps the old pace for an unchanged goal
    if quiet then actor:SetWalkType('walk') end
  end,
})
