local Siege = bgNPC.Siege
bgNPC.States.Register('siege', 'danger', {
  pre_start = function(actor, _, data)
    if not data.entry then data.entry, data.member = Siege.Start(actor) end
    if not data.entry or not data.member or data.entry.finished then return true end
  end,
  start = function(actor, _, data)
    Siege.Quiet(actor, data)
    if actor == data.entry.operator then Siege.Say(actor, 'police_siege_position') end
  end,
  stop = function(actor, _, data) Siege.Detach(actor, data) end,
  update = function(actor, _, data)
    local entry, member, now = data.entry, data.member, CurTime()
    if entry.finished or entry.cancelled or actor:HasNoEnemies() then
      Siege.Finish(entry)
      return
    end

    local operator = actor == entry.operator
    if not operator and Siege.Inside(actor, entry) then
      -- ran into the target's room before the siege: back to the fight, the siege goes on without it
      data.left, entry.members[actor] = true, nil
      actor:SetState('defense', nil, true)
      return
    end

    local pos = member.slot
    if operator and entry.phase ~= 'position' and entry.phase ~= 'wait' and entry.phase ~= 'hold' then
      -- the operator opens the door and throws/releases from the same spot; the hold phase sends it back to its slot
      pos = entry.portal.center + entry.portal.normal * 60
      pos.z = entry.portal.floor + 2
    end

    if data.animation then
      local info = bgNPC.Animator.Get(actor:GetNPC())
      if not info and now < data.release_at then
        Siege.Finish(entry)
        return
      end

      if now >= data.release_at and not data.released then
        local ok = entry.phase == 'door' and Siege.Open(actor, entry) or (entry.phase == 'payload' and Siege.Payload(actor, entry))
        if ok then
          data.released = true
          if entry.phase == 'door' then -- the leaf moves: the next step starts at once
            data.animation_until = now
          end
        elseif entry.phase == 'payload' and now < data.release_at + 1.5 then
          return -- the leaf may still be swinging
        else
          Siege.Finish(entry)
          return
        end
      end

      if now >= data.animation_until then
        actor:StopStaticSequence()
        data.animation, data.released = nil, nil
        if entry.phase == 'door' then
          entry.phase, entry.open_until = 'opening', now + 4
        else
          entry.phase, entry.hold_until = 'hold', now + 6
        end
      end
      return
    end

    if not Siege.Reach(actor, pos) then return end
    if not operator or entry.phase == 'position' then
      Siege.Wait(actor)
      return
    end

    if entry.phase == 'wait' then
      Siege.Wait(actor)
      if now >= entry.wait_until then entry.phase = Siege.Closed(entry.portal) and 'door' or 'payload' end
      return
    end

    if entry.phase == 'opening' then
      if not Siege.Closed(entry.portal, true) then
        entry.phase = 'payload'
      elseif not data.reopened and now > entry.open_until - 3 then
        -- A frozen actor can block the leaf during the gesture; retry once after stepping outside its sweep.
        data.reopened = true
        Siege.Open(actor, entry)
      elseif now > entry.open_until then
        Siege.Finish(entry)
      end
      return
    end

    if entry.phase == 'hold' then
      Siege.Wait(actor)
      if now >= entry.hold_until then Siege.Finish(entry) end
      return
    end

    actor:GetNPC():SetAngles(Angle(0, (-entry.portal.normal):Angle().y, 0))
    local sequence = entry.sequence
    if entry.phase == 'door' then sequence = Siege.DoorAction(actor, entry) end
    if not sequence or not actor:IsValidSequence(sequence) then
      Siege.Finish(entry)
      return
    end

    local info = Siege.Animate(actor, sequence)
    if not info then
      Siege.Finish(entry)
      return
    end

    data.animation, data.animation_until = true, info.stop_time
    if operator then Siege.Say(actor, entry.phase == 'door' and 'police_siege_breach' or 'police_siege_' .. entry.kind) end
    data.release_at = now + info.time * 0.55
  end,
})
