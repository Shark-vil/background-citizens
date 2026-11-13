local Doors = bgNPC.Doors
local function Leave(actor)
  actor.door_hold_cooldown = CurTime() + 20
  actor:SetState(actor:HasNoEnemies() and 'none' or actor:GetStateData().spot.resume, nil, true)
end

-- The shared body API handles both NavMesh NextBots and engine NPC schedules.
local function Reach(actor, pos)
  if actor:GetPos():DistToSqr(pos) <= 32 ^ 2 then
    actor:StopWalk()
    actor:GetBody():StopMoving()
    return true
  end

  if actor:GetPos():DistToSqr(pos) > 180 ^ 2 then
    actor:WalkToPos(pos, 'run')
  else
    actor:StopWalk()
    actor:GetBody():MoveTo(pos, true)
  end
end

bgNPC.States.Register('hold_door', 'danger', {
  pre_start = function(actor, _, data)
    data.spot = Doors.Find(actor, actor:GetEnemy())
    if not Doors.Reserve(actor, data.spot) then return true end
    data.spot.resume = actor:GetState()
  end,
  start = function(_, _, data) data.until_time = CurTime() + 10 end,
  stop = function(actor)
    Doors.Release(actor)
    actor.door_hold_cooldown = CurTime() + 20
  end,
  update = function(actor, _, data)
    local spot, now = data.spot, CurTime()
    if not IsValid(spot.door) or not IsValid(spot.enemy) or spot.enemy:Health() <= 0 or actor:HasNoEnemies() or now > data.until_time then
      Leave(actor)
      return
    end

    if (spot.enemy:GetPos() - spot.center):Dot(spot.normal) > 0 then
      Leave(actor)
      return
    end

    local npc = actor:GetNPC()
    if not data.closing then
      if not bgNPC.Util.IsDoorOpen(spot.door) then
        Leave(actor)
        return
      end

      if not Reach(actor, spot.stage) then return end
      if not Doors.Close(spot) then
        Leave(actor)
        return
      end

      data.closing, data.until_time = true, now + 4
      return
    end

    if not Doors.IsClosed(spot.door) then
      if spot.bracing then Leave(actor) end
      return
    end

    if spot.bracing then return end
    if not Reach(actor, spot.stand) then return end
    local floor = Doors.Floor(actor, spot.stand, spot.door)
    if not floor then
      Leave(actor)
      return
    end

    npc:SetPos(floor)
    npc:SetAngles(spot.ang)
    local seq = Doors.Sequence(actor)
    if not seq or not actor:PlayStaticSequence(seq, true) then
      Leave(actor)
      return
    end

    spot.bracing, data.until_time = true, now + 12
  end,
})

bgNPC.States.Register('breach_door', 'danger', {
  pre_start = function(actor, _, data)
    data.spot = Doors.Blocker(actor, actor:GetEnemy())
    if not data.spot then return true end
    data.approach = Doors.Floor(actor, data.spot.center - data.spot.normal * 54, data.spot.door)
    if not data.approach then return true end
  end,
  start = function(_, _, data) data.until_time = CurTime() + 8 end,
  update = function(actor, _, data)
    if CurTime() > data.until_time or Doors.Blocker(actor, actor:GetEnemy()) ~= data.spot then
      actor:SetState('defense')
      return
    end

    if not Reach(actor, data.approach) then return end
    if not data.kick_at then
      local npc = actor:GetNPC()
      local floor = Doors.Floor(actor, data.approach, data.spot.door)
      if not floor then
        actor:SetState('defense')
        return
      end

      npc:SetPos(floor)
      npc:SetAngles(Angle(0, data.spot.normal:Angle().y, 0))
      data.kick_at = CurTime() + 0.5
      for _, seq in ipairs({'kickdoorbaton', 'kickdoor', 'meleeattack01'}) do
        if actor:IsValidSequence(seq) and actor:PlayStaticSequence(seq) then
          data.kick_at = CurTime() + npc:SequenceDuration(npc:LookupSequence(seq)) * 0.6
          break
        end
      end
    elseif CurTime() >= data.kick_at then
      Doors.Breach(actor, data.spot)
      actor:SetState('defense')
    end
  end,
})
