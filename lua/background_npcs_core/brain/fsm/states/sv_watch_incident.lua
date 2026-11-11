--[[
	watch_incident: onlookers. Every actor death outside a vehicle is an incident for INCIDENT_TIME seconds,
	from CALM_DELAY after it (the shooting is usually over by then). Calm civilians walking or idling within
	SEARCH_DIST come one by one (CHANCE per check, up to MAX_WATCHERS), stand in a ring around the spot,
	stare at it, say a line and go on after WATCH_TIME. A gunshot scares them off like any calm actor.
	State data: { incident = <incident> }.
--]]
local SEARCH_DIST_SQR = 1500 ^ 2
local INCIDENT_TIME = 45
local CALM_DELAY = 5
local MAX_WATCHERS = 4
local CHANCE = 35
local RING_MIN, RING_MAX = 150, 280
local REACH_DIST_SQR = 70 ^ 2
local WATCH_TIME_MIN, WATCH_TIME_MAX = 12, 25
local GIVE_UP_TIME = 25 -- can't reach the spot
local VOICE_CHANCE = 60
local SEQUENCES = {'LineIdle01', 'LineIdle02', 'LineIdle03', 'LineIdle04'}
local incidents = {}
hook.Add('BGN_OnKilledActor', 'BGN_WatchIncident', function(actor)
  if actor:InVehicle() then return end
  local npc = actor:GetNPC()
  if not IsValid(npc) then return end
  incidents[#incidents + 1] = {
    pos = npc:GetPos(),
    time = CurTime(),
    watchers = {}
  }
end)

local function CountWatchers(incident)
  local count = 0
  for watcher in pairs(incident.watchers) do
    if watcher:IsAlive() and watcher:HasState('watch_incident') and watcher:GetStateData().incident == incident then
      count = count + 1
    else
      incident.watchers[watcher] = nil
    end
  end
  return count
end

timer.Create('BGN_WatchIncidents', 2, 0, function()
  local now = CurTime()
  for i = #incidents, 1, -1 do
    local incident = incidents[i]
    if incident.time + INCIDENT_TIME < now then
      table.remove(incidents, i)
    elseif incident.time + CALM_DELAY < now and CountWatchers(incident) < MAX_WATCHERS then
      for _, actor in ipairs(bgNPC.Actors.GetAll()) do
        if actor:IsAlive() and actor:IsCivilian() and not actor:InVehicle() and actor:HasNoEnemies() and actor:HasState({'walk', 'idle'}) and actor:GetPos():DistToSqr(incident.pos) < SEARCH_DIST_SQR and bgNPC.Util.Chance(CHANCE) then
          actor:SetState('watch_incident', {
            incident = incident
          })

          if actor:HasState('watch_incident') then
            incident.watchers[actor] = true
            break -- one per check: they gather one by one
          end
        end
      end
    end
  end
end)

bgNPC.States.Register('watch_incident', 'calm', {
  start = function(actor, _, data)
    -- a spot on the ring, on the actor's side of the incident
    local pos = data.incident.pos
    local dir = actor:GetPos() - pos
    dir.z = 0
    local ang = dir:Angle()
    ang:RotateAroundAxis(vector_up, math.random(-50, 50))
    data.spot = pos + ang:Forward() * math.random(RING_MIN, RING_MAX)
    data.give_up = CurTime() + GIVE_UP_TIME
  end,
  stop = function(actor) actor:StopStaticSequence() end,
  update = function(actor, _, data)
    local now = CurTime()
    if data.leave then
      if data.leave < now then
        actor:RandomState()
        return
      end
    elseif data.give_up < now then
      actor:RandomState()
      return
    elseif actor:GetPos():DistToSqr(data.spot) > REACH_DIST_SQR then
      bgNPC.MoveToPoint(actor, data, data.spot, false)
      return
    else
      actor:StopWalk()
      actor:GetBody():StopMoving()
      local npc = actor:GetNPC()
      npc:SetAngles(Angle(0, (data.incident.pos - npc:GetPos()):Angle().y, 0))
      data.leave = now + math.random(WATCH_TIME_MIN, WATCH_TIME_MAX)
      data.sequence = SEQUENCES[math.random(#SEQUENCES)]
      if not actor:IsValidSequence(data.sequence) then data.sequence = nil end
      if bgNPC.Util.Chance(VOICE_CHANCE) then timer.Simple(math.Rand(0.5, 4), function() actor:Voice('watch_incident') end) end
    end

    if data.sequence and not actor:IsAnimationPlayed() then actor:PlayStaticSequence(data.sequence, true) end
  end,
})
