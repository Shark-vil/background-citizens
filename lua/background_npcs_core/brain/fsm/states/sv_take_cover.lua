--[[
	take_cover: an armed actor runs to the nearest nav point the enemy can't see at crouch height, crouches
	there for HIDE_TIME, then fights (defense) for FIGHT_TIME before GOAP sends it to cover again.
	actor.cover_until is the GOAP fact "in_cover" (brain/goap/sv_goap_actions.lua).
	State data: { cover = <Vector> }.
--]]
local SEARCH_RADIUS = 1000
local MIN_ENEMY_DIST_SQR = 300 ^ 2
local MAX_TRACES = 24
local REACH_DIST_SQR = 60 ^ 2
local HIDE_TIME = 3
local FIGHT_TIME = 10
local GIVE_UP_TIME = 8
local HEAD = Vector(0, 0, 36) -- a crouching head
local CROUCH = {'Crouch_Idle_Pistol', 'crouchidle', 'Crouch_IdleD'}
local function IsHidden(pos, enemy)
  return util.TraceLine({
    start = enemy:EyePos(),
    endpos = pos + HEAD,
    mask = MASK_BLOCKLOS,
    filter = enemy
  }).Hit
end

-- @return Vector|nil the nearest point near the actor hidden from the enemy
function bgNPC.FindCover(actor, enemy)
  local origin, enemy_pos = actor:GetPos(), enemy:GetPos()
  local candidates = {}
  for _, point in ipairs(bgNPC.Points.GetInRadius(origin, SEARCH_RADIUS)) do
    local pos = point:GetPos()
    if pos:DistToSqr(enemy_pos) >= MIN_ENEMY_DIST_SQR then
      candidates[#candidates + 1] = {
        pos = pos,
        dist = pos:DistToSqr(origin)
      }
    end
  end

  table.SortByMember(candidates, 'dist', true)
  for i = 1, math.min(#candidates, MAX_TRACES) do
    if IsHidden(candidates[i].pos, enemy) then return candidates[i].pos end
  end
end

bgNPC.States.Register('take_cover', 'danger', {
  pre_start = function(actor, _, data)
    local enemy = actor:GetEnemy()
    if IsValid(enemy) and not bgNPC.Vision.HasLineOfSight(actor:GetNPC(), enemy, 'cover') then return 'defense' end
    data.cover = IsValid(enemy) and bgNPC.FindCover(actor, enemy)
    if not data.cover then return 'defense' end
  end,
  start = function(_, _, data) data.give_up = CurTime() + GIVE_UP_TIME end,
  stop = function(actor) actor:StopStaticSequence() end,
  update = function(actor, _, data)
    local now = CurTime()
    local enemy = actor:GetEnemy()
    -- hidden behind the cover is the point: only the way there ends when the enemy loses sight of the actor
    if not data.hide_until and IsValid(enemy) and not bgNPC.Vision.HasLineOfSight(actor:GetNPC(), enemy, 'cover') then
      actor:SetState('defense')
      return
    end

    if not IsValid(enemy) or (not data.hide_until and data.give_up < now) then
      if actor:HasNoEnemies() then
        actor:RandomState()
      else
        actor:SetState('defense')
      end
      return
    end

    if not data.hide_until then
      if actor:GetPos():DistToSqr(data.cover) > REACH_DIST_SQR then
        bgNPC.MoveToPoint(actor, data, data.cover, true)
      else
        actor:StopWalk()
        actor:GetBody():StopMoving()
        local npc = actor:GetNPC()
        npc:SetAngles(Angle(0, (enemy:GetPos() - npc:GetPos()):Angle().y, 0))
        data.hide_until = now + HIDE_TIME
      end
      return
    end

    if data.hide_until < now then
      actor.cover_until = now + FIGHT_TIME
      actor:SetState('defense')
      return
    end

    if not actor:IsAnimationPlayed() then
      for _, name in ipairs(CROUCH) do
        if actor:IsValidSequence(name) then
          actor:PlayStaticSequence(name, true)
          break
        end
      end
    end
  end,
})
