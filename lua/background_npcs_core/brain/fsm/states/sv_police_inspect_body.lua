--[[
	police_inspect_body: a calm officer walks to a fresh body, crouches over it, reports it on the radio,
	writes it down and goes back to patrolling. Every actor death (not in a vehicle) leaves a body for
	BODY_TIME seconds; the nearest free officer (walking or idle, within SEARCH_DIST) takes it, so bodies left
	by a shoot-out are inspected once the officers calm down. A body revived by a medic is dropped.
	State data: { body = <body> }.
--]]
local SEARCH_DIST_SQR = 2000 ^ 2
local BODY_TIME = 60
local REACH_DIST_SQR = 90 ^ 2
local RUN_DIST_SQR = 600 ^ 2 -- farther than this the officer runs to the body, closer it walks
local REVIVED_DIST_SQR = 100 ^ 2
local SCENE_DIST_SQR = 500 ^ 2 -- bodies this close are one scene: one officer for all of them
local STAGE_TIME = 5
local GIVE_UP_TIME = 30 -- can't reach the body
-- first sequence the model has
local CROUCH = {'Crouch_Idle_Pistol', 'crouchidle', 'Crouch_IdleD'}
local STAND = {'canal5bidle1', 'canal5bidle2'}
local bodies = {}
local function PickSequence(actor, list)
  for _, name in ipairs(list) do
    if actor:IsValidSequence(name) then return name end
  end
end

hook.Add('BGN_OnKilledActor', 'BGN_PoliceInspectBody', function(actor)
  if actor:InVehicle() then return end
  local npc = actor:GetNPC()
  if not IsValid(npc) then return end
  bodies[#bodies + 1] = {
    pos = npc:GetPos(),
    time = CurTime()
  }
end)

hook.Add('BGN_ActorRevived', 'BGN_PoliceInspectBody', function(_, call)
  for _, body in ipairs(bodies) do
    if body.pos:DistToSqr(call.pos) < REVIVED_DIST_SQR then body.done = true end
  end
end)

local function IsInspecting(officer, body)
  return officer:IsAlive() and officer:HasState('police_inspect_body') and officer:GetStateData().body == body
end

-- @return table|nil the nearest calm officer on foot
local function FindOfficer(pos)
  local best, best_dist = nil, SEARCH_DIST_SQR
  for _, officer in ipairs(bgNPC.Actors.GetByTeam('police')) do
    if officer:IsAlive() and not officer:InVehicle() and officer:HasNoEnemies() and officer:HasState({'walk', 'idle'}) then
      local dist = officer:GetPos():DistToSqr(pos)
      if dist < best_dist then best, best_dist = officer, dist end
    end
  end
  return best
end

-- @return boolean another officer already handles a body at this scene
local function SceneTaken(body)
  for _, other in ipairs(bodies) do
    if other ~= body and not other.done and other.officer and IsInspecting(other.officer, other) and other.pos:DistToSqr(body.pos) < SCENE_DIST_SQR then return true end
  end
  return false
end

timer.Create('BGN_PoliceInspectBodies', 2, 0, function()
  local now = CurTime()
  for i = #bodies, 1, -1 do
    local body = bodies[i]
    if body.done or body.time + BODY_TIME < now then
      table.remove(bodies, i)
    elseif not bgNPC.Medics.IsHandling(body.pos) and (not body.officer or not IsInspecting(body.officer, body)) and not SceneTaken(body) then
      body.officer = FindOfficer(body.pos)
      if body.officer then
        body.officer:SetState('police_inspect_body', {
          body = body
        })
      end
    end
  end
end)

bgNPC.States.Register('police_inspect_body', 'calm', {
  start = function(actor, _, data) data.give_up = CurTime() + GIVE_UP_TIME end,
  stop = function(actor) actor:StopStaticSequence() end,
  update = function(actor)
    local data = actor:GetStateData()
    local body = data.body
    local now = CurTime()
    -- a threat ends the paperwork at once: the officer answers it like an attack
    if not actor:HasNoEnemies() then
      local reaction = actor:GetReactionForDamage(actor:GetNearEnemy())
      actor:SetState((reaction == 'ignore' or reaction == 'none') and 'defense' or reaction)
      return
    end

    if not body or body.done or data.give_up < now then
      actor:RandomState()
      return
    end

    if not data.stage then
      if actor:GetPos():DistToSqr(body.pos) > REACH_DIST_SQR then
        bgNPC.MoveToPoint(actor, data, body.pos, actor:GetPos():DistToSqr(body.pos) > RUN_DIST_SQR)
        return
      end

      actor:StopWalk()
      actor:GetBody():StopMoving()
      local npc = actor:GetNPC()
      npc:SetAngles(Angle(0, (body.pos - npc:GetPos()):Angle().y, 0))
      actor:Voice('police_body_arrive')
      data.stage = 1 -- 1 looks at the body, 2 reports on the radio, 3 writes it down
      data.next_stage = now + STAGE_TIME
      data.give_up = now + STAGE_TIME * 4
    elseif data.next_stage <= now then
      actor:StopStaticSequence()
      data.stage = data.stage + 1
      data.next_stage = now + STAGE_TIME
      if data.stage == 2 then
        actor:Voice('police_body_report', 'npc/metropolice/vo/sociocide.wav')
      elseif data.stage == 3 then
        actor:Voice('police_body_notes')
      else
        body.done = true
        -- the rest of the scene was seen too
        for _, other in ipairs(bodies) do
          if other.pos:DistToSqr(body.pos) < SCENE_DIST_SQR then other.done = true end
        end

        actor:RandomState()
        return
      end
    end

    local sequence = PickSequence(actor, data.stage == 1 and CROUCH or STAND)
    if sequence then actor:PlayStaticSequence(sequence, true) end
  end,
})
