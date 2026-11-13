--[[
	Negotiation: a player who shields himself with a hostage is not shot at, he is talked to.
	A hostage is any frightened non-police actor within HOSTAGE_RADIUS of the target that stands closer to the officer
	than the target does (so a flank or rear approach, where the hostage is behind the target, does not count).
	Every officer who sees such a shield holds fire. After WAIT_TIME the talks fail, the officers shoot again.
	The talks also fail the moment the player kills anybody. A failed negotiation is not offered again to that
	player until he is arrested, drops a wanted level, dies, or BLOCK_TIME passes.
--]]
local HOSTAGE_RADIUS = 300
local WAIT_TIME, WARNING_TIME, BLOCK_TIME, LOST_TIME = 20, 5, 120, 3
local FEAR_STATES = {'fear', 'run_from_danger', 'dyspnea_danger'}
local Negotiation = {}
bgNPC.Negotiation = Negotiation
local talks, blocked, holding = {}, setmetatable({}, {__mode = 'k'}), {}
-- @return actor|nil the hostage the target hides behind, seen from the officer
function Negotiation.Hostage(officer, target)
  local origin, target_pos = officer:GetPos(), target:GetPos()
  local limit = target_pos:DistToSqr(origin)
  for _, actor in ipairs(bgNPC.Actors.GetInRadius(target_pos, HOSTAGE_RADIUS)) do
    if actor ~= officer and actor:IsAlive() and not actor:HasTeam('police') and actor:HasState(FEAR_STATES)
      and actor:GetPos():DistToSqr(origin) < limit then return actor end
  end
end

-- Capabilities are the only way to stop an engine NPC from firing; a NextBot checks actor.hold_fire itself.
local function HoldFire(actor, on)
  if (actor.hold_fire or false) == on then return end
  actor.hold_fire = on or nil
  local npc = actor:GetNPC()
  if not IsValid(npc) or not npc:IsNPC() then return end
  if on then
    actor.hold_fire_caps = bit.band(npc:CapabilitiesGet(), CAP_USE_WEAPONS)
    npc:CapabilitiesRemove(CAP_USE_WEAPONS)
  elseif actor.hold_fire_caps then
    npc:CapabilitiesAdd(actor.hold_fire_caps)
    actor.hold_fire_caps = nil
  end
end

local function Fail(target, officer)
  talks[target] = nil
  blocked[target] = CurTime() + BLOCK_TIME
  if officer then officer:Voice('police_negotiate_failed') end
end

local function Tick()
  local now, held, speaker = CurTime(), {}, {}
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    local enemy = actor:HasTeam('police') and actor:IsAlive() and not actor.siege and actor:GetEnemy()
    if IsValid(enemy) and enemy:IsPlayer() and enemy:Alive() and (blocked[enemy] or 0) <= now and Negotiation.Hostage(actor, enemy) then
      local talk = talks[enemy]
      if not talk then
        talk = {deadline = now + WAIT_TIME}
        talks[enemy] = talk
        actor:Voice('police_negotiate_offer')
      end

      talk.lost = nil
      HoldFire(actor, true)
      held[actor], speaker[enemy] = true, speaker[enemy] or actor
    end
  end

  for actor in pairs(holding) do
    if not held[actor] then HoldFire(actor, false) end
  end

  holding = held
  for target, talk in pairs(talks) do
    local officer = speaker[target]
    if not IsValid(target) then
      talks[target] = nil
    elseif not officer then
      -- the shield flickers while the officers move: the talks end only when it stays gone
      talk.lost = talk.lost or now
      if now - talk.lost > LOST_TIME then talks[target] = nil end
    elseif talk.failed or now >= talk.deadline then
      Fail(target, officer)
    elseif not talk.warned and now >= talk.deadline - WARNING_TIME then
      talk.warned = true
      officer:Voice('police_negotiate_warning')
    end
  end
end

timer.Create('BGN_Negotiation', 0.5, 0, Tick)
-- Any kill by the negotiated player breaks the talks.
hook.Add('PostEntityTakeDamage', 'BGN_Negotiation', function(ent, damage)
  local attacker = bgNPC.Combat.ResolveVehicleAttacker(damage:GetAttacker())
  local talk = IsValid(attacker) and talks[attacker]
  if talk and ent ~= attacker and ent:Health() <= 0 and (ent:IsNPC() or ent:IsNextBot() or ent:IsPlayer()) then talk.failed = true end
end)

local function Reset(target) if IsValid(target) then blocked[target], talks[target] = nil, nil end end
hook.Add('PlayerDeath', 'BGN_Negotiation', Reset)
hook.Add('BGN_WantedLevelDown', 'BGN_Negotiation', Reset)
hook.Add('BGN_PlayerArrest', 'BGN_Negotiation', Reset)
