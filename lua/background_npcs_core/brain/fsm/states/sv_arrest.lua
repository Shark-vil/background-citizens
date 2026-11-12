local WantedModule = bgNPC.Modules.Get('wanted')
local ArrestModule = bgNPC.Modules.Get('player_arrest')
-- An actor gives up only below half of its health, before that it never does.
local function IsHurt(ent)
  return ent:Health() < ent:GetMaxHealth() * 0.5
end

-- An officer in the arrest state stays in it. The only way out is being attacked right now; the state's own exits
-- (target gone, arrest done, the target cannot be arrested) go through Leave().
local ATTACKED_WINDOW = 1.5
local function Leave(actor, change_state)
  actor.arrest_release = true
  change_state()
  actor.arrest_release = nil
end

hook.Add('BGN_PreSetState', 'BGN_ArrestHold', function(actor, state)
  if state == 'arrest' or not actor:HasState('arrest') or actor.arrest_release then return end
  if CurTime() - (actor.last_attacked_at or -ATTACKED_WINDOW) <= ATTACKED_WINDOW then return end
  return true
end)

hook.Add('BGN_PreCallForHelp', 'BGN_PlayerArrest', function(actor, enemy)
  if not ArrestModule:HasTarget(enemy) then return end
  return ArrestModule:GetTarget(enemy).arrested
end)

hook.Add('BGN_OnKilledActor', 'BGN_PlayerArrest', function(_, attacker)
  if not ArrestModule:HasTarget(attacker) then return end
  local ArrestComponent = ArrestModule:GetTarget(attacker)
  if not ArrestComponent.arrested then return end
  ArrestModule:NotSubjectToArrest(attacker)
end)

hook.Add('BGN_PreReactionTakeDamage', 'BGN_PlayerArrest', function(attacker, target, reaction)
  if not GetConVar('bgn_arrest_mode'):GetBool() then return end
  if attacker:IsPlayer() and WantedModule:HasWanted(attacker) then return end
  local TargetActor = bgNPC.Actors.Get(target)
  local AttackerActor = bgNPC.Actors.Get(attacker)
  -- players and actors (NextBot actors too, not IsNPC): a gangster in a shoot-out may give up
  if not attacker:IsPlayer() and not AttackerActor then return end
  if not ArrestModule:HasTarget(attacker) then
    local PoliceActor
    if TargetActor and TargetActor:HasTeam('police') then
      PoliceActor = TargetActor
    else
      PoliceActor = ArrestModule:FoundPoliceInRadius(attacker)
      if not PoliceActor then
        PoliceActor = ArrestModule:FoundPoliceInRadius(target)
        if not PoliceActor then return end
      end
    end

    local enemy = bgNPC.Combat.ResolveEnemy(PoliceActor, target, attacker)
    if enemy ~= attacker then
      -- the officer shot a non-police actor (a gangster): the arrest below skips its damage reaction, so it answers here
      if TargetActor and TargetActor ~= PoliceActor and not TargetActor:HasTeam('police') and reaction and TargetActor:EqualStateGroup('calm') then
        TargetActor:AddEnemy(attacker)
        TargetActor:SetState(reaction, nil, true)
      end

      target = attacker
      attacker = enemy
      TargetActor = bgNPC.Actors.Get(target)
      AttackerActor = bgNPC.Actors.Get(attacker)
    end

    ArrestModule:AddTarget(attacker, PoliceActor)
    if PoliceActor:InVehicle() then PoliceActor:ExitVehicle() end
    -- the surrender first: the arrest state checks it on start and shoots a target that isn't giving up
    if AttackerActor and not AttackerActor:HasState('arrest_surrender') and IsHurt(attacker) and bgNPC.Util.Chance(5) then
      AttackerActor:AddTarget(PoliceActor:GetNPC())
      AttackerActor:SetState('arrest_surrender', nil, true)
    end

    PoliceActor:RemoveAllTargets()
    PoliceActor:AddTarget(attacker)
    PoliceActor:SetState('arrest')
    if TargetActor and TargetActor ~= PoliceActor then
      TargetActor:RemoveAllTargets()
      TargetActor:AddEnemy(attacker)
      if not TargetActor:EqualStateGroup('danger') then TargetActor:SetState('fear') end
    end
    return false
  else
    local ArrestComponent = ArrestModule:GetTarget(attacker)
    if not ArrestComponent then return end
    if AttackerActor and not AttackerActor:HasState('arrest_surrender') and bgNPC.Util.Chance(10) and IsHurt(attacker) then
      ArrestModule:UpdatePolice(attacker)
      local policeActor = ArrestComponent.policeActor
      if policeActor and policeActor:IsAlive() then
        ArrestModule:UpdateArrest(attacker)
        AttackerActor:AddTarget(policeActor:GetNPC())
        AttackerActor:SetState('arrest_surrender', nil, true)
        policeActor:AddTarget(attacker)
        policeActor:SetState('arrest', nil, true)
        return true
      end
    end

    if ArrestComponent.arrested then
      ArrestComponent.damege_count = ArrestComponent.damege_count + 1
      if TargetActor then
        if TargetActor:HasTeam('police') then
          if target:Health() > 20 and ArrestComponent.damege_count <= 5 then
            TargetActor:AddTarget(attacker)
            TargetActor:SetState('arrest')
          end
        elseif TargetActor:EqualStateGroup('calm') then
          TargetActor:AddEnemy(attacker)
          TargetActor:SetState(reaction, nil, true)
        end
      end
      return false
    end
  end
end)

hook.Add('BGN_AddActorEnemy', 'BGN_ArrestedNotEnemy', function(_, ent) if ent.bgn_arrested then return true end end)
local function OnSetDefense(actor)
  local target = actor:GetFirstTarget()
  local TargetActor = bgNPC.Actors.Get(target)
  if not IsValid(target) or not ArrestModule:CanArrest(target) or (TargetActor and not TargetActor:HasState('arrest_surrender')) then
    actor:RemoveAllTargets()
    if IsValid(target) then
      actor:AddEnemy(target)
      if target:IsPlayer() and target:Alive() and ArrestModule:HasTarget(target) and GetConVar('bgn_arrest_mode'):GetBool() and GetConVar('bgn_enable_wanted_mode'):GetBool() and not bgNPC.Modes.IsPeaceful() and not WantedModule:HasWanted(target) then WantedModule:AddWanted(target) end
    end
    return 'defense'
  end
end

-- Detention is shared by every officer of the arrest, so each officer only adds or drops its own hold:
-- an officer far away used to reset the flag every tick and restart the warning and the countdown.
local function SetHold(ArrestComponent, actor, hold)
  local holders = ArrestComponent.holders
  holders[actor] = hold or nil
  for holder in pairs(holders) do
    if not IsValid(holder:GetNPC()) then holders[holder] = nil end
  end

  ArrestComponent.detention = next(holders) ~= nil
end

bgNPC.States.Register('arrest', 'guarded', {
  pre_start = function(actor) return OnSetDefense(actor) end,
  update = function(actor, state, data)
    local npc = actor:GetNPC()
    local target = actor:GetFirstTarget()
    local TargetActor = bgNPC.Actors.Get(target)
    local ArrestComponent = ArrestModule:GetTarget(target)
    if not IsValid(target) or actor:TargetsCount() == 0 or not ArrestComponent then
      Leave(actor, function() actor:RandomState() end)
      return
    end

    local defense = OnSetDefense(actor)
    if defense then
      Leave(actor, function() actor:SetState(defense) end)
      return
    end

    local primary = not bgNPC.Combat.CanPoliceUseStunstick(actor, target)
    local weapon = primary and actor:GetActorWeapon() or 'weapon_stunstick'
    if not weapon or (primary and weapon == 'weapon_stunstick') then weapon = 'weapon_pistol' end
    bgNPC.Combat.EquipActor(actor, weapon, true)
    npc.bgn_arrest_aim_target = primary and target or nil
    actor:GetBody():SetEnemy(NULL)
    actor:GetBody():SetAlertLevel('alert')
    if npc:GetPos():DistToSqr(target:GetPos()) > 40000 then
      if actor:IsAnimationPlayed() then actor:ResetSequence() end
      actor:WalkToTarget(target, 'run')
      SetHold(ArrestComponent, actor, false)
    else
      local addArrestTime = GetConVar('bgn_arrest_time'):GetFloat()
      local eyeAngles = target:EyeAngles()
      if not ArrestComponent.detention then ArrestComponent.arrest_time = CurTime() + addArrestTime end
      if not target:IsPlayer() or eyeAngles.x > 40 then
        local was_detention = ArrestComponent.detention
        SetHold(ArrestComponent, actor, true)
        if not was_detention then
          actor:Voice('police_arrest_warning', bgNPC.cfg.arrest['warning_sound'])
          if target:IsPlayer() then target:ChatPrint(bgNPC.cfg.arrest['warning_text']) end
        end
      else
        SetHold(ArrestComponent, actor, false)
        if actor:IsAnimationPlayed() then actor:ResetSequence() end
      end

      if not ArrestComponent.detention and ArrestComponent.notify_order_time < CurTime() then
        ArrestComponent.notify_order_time = CurTime() + 3
        if target:IsPlayer() then target:ChatPrint(bgNPC.cfg.arrest['order_text']) end
        actor:Voice('police_arrest_order', bgNPC.cfg.arrest['order_sound'])
      elseif ArrestComponent.detention then
        local time = ArrestComponent.arrest_time - CurTime()
        if time <= 0 then
          ArrestModule:RemoveTarget(target)
          data.arrested = true
          actor:Voice('police_arrested')
          local handled = hook.Run('BGN_PlayerArrest', target, actor)
          bgNPC.Combat.ResetPoliceThreat(target)
          if not handled then
            target:EmitSound('background_npcs/handcuffs_sound1.mp3')
            if not target:IsPlayer() then
              -- The body lingers for a few seconds: nobody may take it for a wanted enemy again.
              target.bgn_arrested = true
              WantedModule:RemoveWanted(target)
              if TargetActor then
                TargetActor:RemoveAllTargets()
                TargetActor:RemoveAllEnemies()
                TargetActor:StateLock(true)
              end

              local weapon = target:GetActiveWeapon()
              if IsValid(weapon) then weapon:Remove() end
              if TargetActor and TargetActor:IsValidSequence('arrestcurious') then
                TargetActor:PlayStaticSequence('arrestcurious', false, nil, function()
                  -- one-shot: a loop restarted it mid-pose
                  TargetActor:PlayStaticSequence('arrestidle', true)
                  bgNPC.Util.FadeRemove(target, .5)
                  return true -- Keep the idle pose while fading; ResetSequence would release the NPC.
                end)
              elseif TargetActor and TargetActor:IsValidSequence('checkmale') then
                TargetActor:PlayStaticSequence('checkmale', false, nil, function()
                  TargetActor:PlayStaticSequence('checkmalepost', true)
                  bgNPC.Util.FadeRemove(target, .5)
                  return true
                end)
              else
                bgNPC.Util.FadeRemove(target)
              end
            else
              target:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 3)
              target:KillSilent()
            end
          end

          for _, selectActor in ipairs(bgNPC.Actors.GetAll()) do
            selectActor:RemoveTarget(target)
            selectActor:RemoveEnemy(target)
          end
        else
          if target:IsPlayer() and ArrestComponent.notify_arrest_time < CurTime() then
            target:ChatPrint(string.Replace(bgNPC.cfg.arrest['arrest_notify'], '%time%', math.floor(time)))
            ArrestComponent.notify_arrest_time = CurTime() + 1
          end
        end
      end

      if primary and not data.arrested and npc:IsNPC() then
        local ang = (target:GetPos() - npc:GetPos()):Angle()
        npc:SetAngles(Angle(0, ang.y, 0))
        local selected = npc:GetActiveWeapon()
        local pistol = IsValid(selected) and (selected:GetClass() == 'weapon_pistol' or selected:GetClass() == 'weapon_357')
        local sequence = npc:SelectWeightedSequence(pistol and ACT_IDLE_ANGRY_PISTOL or ACT_IDLE_ANGRY_SMG1)
        if sequence and sequence >= 0 then actor:PlayStaticSequence(npc:GetSequenceName(sequence), true) end
      elseif not primary and ArrestComponent.detention and npc:IsNPC() then
        local ang = (target:GetPos() - npc:GetPos()):Angle()
        npc:SetAngles(Angle(0, ang.y, 0))
        actor:PlayStaticSequence('canal5bidle1', true)
      end
    end
  end,
  stop = function(actor, state, data)
    local npc = actor:GetNPC()
    if IsValid(npc) then npc.bgn_arrest_aim_target = nil end
    local ArrestComponent = ArrestModule:GetTarget(actor:GetFirstTarget())
    if ArrestComponent then SetHold(ArrestComponent, actor, false) end
    if data.arrested then hook.Run('BGN_PlayerArrestStop', actor, state, data) end
  end
})
