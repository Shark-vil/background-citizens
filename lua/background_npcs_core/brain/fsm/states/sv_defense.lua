local table_RandomBySeq = bgNPC.Table.Random
local REPOSITION_PERIOD = 3
local SLOT_REACHED_SQR = 50 ^ 2
local SLOT_MOVED_SQR = 64 ^ 2
local MELEE_STOP_SQR = 50 ^ 2
local MELEE_ENGINE_DIST_SQR = 700 ^ 2
local WANTED_FIGHT_DIST_SQR = 300 ^ 2 -- a wanted actor fights only this close (retreat turns to defense at 190)
local WANTED_RETREAT_HEALTH = 0.5 -- ...and only below this share of max health
local CAR_CHECK_PERIOD = 2
local CAR_CHANCE = 30
--
-- A player in a vehicle, or an actor in a car (its hidden entity is the enemy)
local function IsEnemyInVehicle(enemy)
  if enemy:IsPlayer() then return enemy:InVehicle() end
  local enemy_actor = bgNPC.Actors.Get(enemy)
  return enemy_actor ~= nil and enemy_actor:InVehicle()
end

-- A melee fighter has to close in. A NextBot is steered at the enemy on every update; an HL2 NPC chases
-- by its own AI nearby, so only a far one is handled (by the ranged code below).
-- @return boolean true if handled
local function ChaseMelee(actor, enemy)
  local body = actor:GetBody()
  local dist_sqr = actor:GetPos():DistToSqr(enemy:GetPos())
  if not body:IsNextBot() then return dist_sqr <= MELEE_ENGINE_DIST_SQR end
  if actor:WalkDestinationExists() then actor:StopWalk() end
  if dist_sqr > MELEE_STOP_SQR then
    body:MoveTo(enemy:GetPos(), true)
  elseif body:IsMoving() then
    body:StopMoving()
  end
  return true
end

-- Squad member (systems/sv_tactical_groups.lua): the body goes straight to the formation slot.
-- The actor walk would stop 150 units short (MOVEMENT_FINISHED_DIST), wider than the formation spacing.
local function MoveToSlot(actor, data, slot)
  local body = actor:GetBody()
  if actor:WalkDestinationExists() then actor:StopWalk() end
  if actor:GetPos():DistToSqr(slot) <= SLOT_REACHED_SQR then
    if data.slot then body:StopMoving() end
    data.slot = nil
    return
  end

  if data.slot and data.slot:DistToSqr(slot) < SLOT_MOVED_SQR and body:IsMoving() then return end
  data.slot = slot
  body:MoveTo(slot, true)
end

bgNPC.States.Register('defense', 'danger', {
  pre_start = function(actor)
    if not actor.weapon then
      -- Self-heal: an always-armed actor (no getting_weapon_chance) may have lost its weapon class.
      -- Actors with a chance lost the roll on spawn; arming them here armed every citizen that
      -- fear sent back to defense.
      local data = actor:GetData()
      local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. actor:GetType())
      if data.weapons and not data.getting_weapon_chance and (not cvar_disable_weapon or not cvar_disable_weapon:GetBool()) then actor.weapon = table_RandomBySeq(data.weapons) end
    end

    if not actor.weapon then return 'fear' end
  end,
  start = function(actor)
    -- an actor that came from fear still has its enemies as D_FR: an NPC won't shoot, a NextBot isn't in combat
    local body = actor:GetBody()
    for _, enemy in ipairs(actor.enemies) do
      if IsValid(enemy) then body:SetDisposition(enemy, D_HT) end
    end

    body:SetAlertLevel('combat')
    if actor:HasTeam('police') then
      local enemy = actor:GetEnemy()
      local npc = actor:GetNPC()
      if IsValid(enemy) and enemy:GetPos():DistToSqr(npc:GetPos()) < 250000 then actor:Voice('police_contact', 'npc/metropolice/vo/defender.wav') end
    end
  end,
  update = function(actor)
    local squad = actor.squad
    local enemy = actor:GetEnemy()
    if not IsValid(enemy) then
      if actor:HasNoEnemies() then actor:RandomState() end
      return
    end

    local data = actor:GetStateData()
    local now = CurTime()
    -- the police took over: a civilian leaves the fight to them
    if (data.next_police_check or 0) <= now then
      data.next_police_check = now + 1
      if actor:IsCivilian() and actor:PoliceFights(enemy) then
        actor:StayOutOfFight()
        actor:SetState('fear')
        return
      end

      -- a wounded wanted actor no longer cornered goes back to hiding
      if actor:IsWanted() and actor:GetHealth() < actor:GetMaxHealth() * WANTED_RETREAT_HEALTH and actor:GetPos():DistToSqr(enemy:GetPos()) > WANTED_FIGHT_DIST_SQR then
        actor:SetState('retreat')
        return
      end
    end

    -- the weapon comes out right away; only the repositioning below is throttled
    if not data.disableWeapon then actor:PrepareWeapon() end
    -- the enemy drives off (a player or an actor in a car): get a car too, before the squad takes over the move.
    -- Police may confiscate one and bandits carjack one when none of their own is near (go_to_police_car).
    if (data.next_car_check or 0) <= now then
      data.next_car_check = now + CAR_CHECK_PERIOD
      if IsEnemyInVehicle(enemy) and bgNPC.Actor.DrivesAway(enemy) and bgNPC.Util.Chance(CAR_CHANCE) then
        actor:SetState('go_to_police_car', {
          seize = actor:HasTeam('police') or actor:HasTeam('bandits')
        })

        if actor:HasState('go_to_police_car') then return end
      end
    end

    local visible = bgNPC.Vision.HasLineOfSight(actor:GetNPC(), enemy, 'combat')
    if not visible then
      local known = actor.enemy_last_position and actor.enemy_last_position[enemy]
      if known and squad and squad.enemy == enemy and squad.squad.formation == 'column' then
        MoveToSlot(actor, data, squad.slot)
      elseif (data.next_move or 0) <= now then
        data.next_move = now + REPOSITION_PERIOD
        if known and actor:GetPos():DistToSqr(known) > SLOT_REACHED_SQR then
          actor:WalkToPos(known, 'run')
        else
          actor:StopWalk()
          actor:GetBody():StopMoving()
        end
      end
      return
    end

    if squad and squad.enemy == enemy then
      MoveToSlot(actor, data, squad.slot)
      return
    end

    data.slot = nil
    if actor:IsMeleeWeapon() and ChaseMelee(actor, enemy) then return end
    if (data.next_move or 0) > now then return end
    data.next_move = now + REPOSITION_PERIOD
    local npc = actor:GetNPC()
    local npc_pos = npc:GetPos()
    local enemy_pos = enemy:GetPos()
    local current_distance = npc_pos:DistToSqr(enemy_pos)
    local is_player_in_vehicle = enemy:IsPlayer() and enemy:InVehicle()
    if current_distance > 490000 then
      if is_player_in_vehicle then
        actor:WalkToTarget(enemy:GetVehicle(), 'run')
      else
        actor:WalkToTarget(enemy, 'run')
      end
    else
      -- Don't yank the NPC into a reposition/retreat schedule while it's
      -- already mid-attack (SCHED_RANGE_ATTACK1/RELOAD/etc.) - doing so was
      -- constantly cancelling shots before they landed.
      if actor:IsExecutingCombatSchedule() then return end
      local node
      local is_melee_weapon = actor:IsMeleeWeapon()
      if not is_melee_weapon and current_distance < 250000 and bgNPC.Vision.HasLineOfSight(npc, enemy) then
        node = bgNPC.Points.GetDistantInRadius(npc_pos + npc:GetForward() * -500, 500)
        actor:WalkToTarget()
        if node then
          actor:WalkToPos(node:GetPos(), 'run')
        else
          local fallback_enemy_position = enemy_pos + enemy:GetForward() * -200
          local fallback_position = npc_pos + npc:GetForward() * -200
          fallback_enemy_position = fallback_enemy_position + Vector(math.random(0, 200), math.random(0, 200), 0)
          fallback_position = fallback_position + Vector(math.random(0, 200), math.random(0, 200), 0)
          if enemy_pos:DistToSqr(fallback_enemy_position) > enemy_pos:DistToSqr(fallback_position) then
            actor:WalkToPos(fallback_enemy_position, 'run')
          else
            actor:WalkToPos(fallback_position, 'run')
          end
        end
      end

      if #actor.walkPath == 0 and not is_melee_weapon then actor:GetBody():MoveAwayFromEnemy() end
    end
  end
})
