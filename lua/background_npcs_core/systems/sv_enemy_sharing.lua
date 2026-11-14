--[[
	Shared enemies: every "bgn_enemy_share_period" seconds an actor that fights someone passes the enemy on to the
	teammates around it that see it and do not know the enemy yet. Without it an officer shoots at a player nobody
	else reacts to (the wanted level is not there yet), and the others keep walking as if nothing happens.
--]]
local RADIUS = 1000
local cvar_period = GetConVar('bgn_enemy_share_period')
-- A scared actor does not spread its panic: the fear would run through the whole crowd.
local function CanShare(actor)
  return actor:IsAlive() and not actor:HasNoEnemies() and not actor:HasState('fear') and (actor.data.gang or not actor:InVehicle())
end

-- The enemy reaches a teammate: a calm one reacts first, the blocked flag is only fresh for an actor asked just now.
local function Warn(other, enemy, source_npc)
  local asked = other:EqualStateGroup('calm')
  if asked then
    other:RemoveAllTargets()
    other:SetState(other:GetReactionForProtect(enemy))
  end

  if not (asked and other.protect_blocked_enemy == enemy) then
    other:AddEnemy(enemy)
    if bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(other, 'share', enemy, nil, source_npc, other:HasEnemy(enemy)) end
  elseif bgNPC.DebugInspector then
    bgNPC.DebugInspector.Emit(other, 'share', enemy, 'reaction_blocked', source_npc, false)
  end
end

local function Share(source)
  local npc = source:GetNPC()
  local gang = source.data.gang
  local enemies = {}
  for i = 1, source.enemies_count do
    local enemy = source.enemies[i]
    -- Police and gangs share known threats even before the enemy attacks again.
    if IsValid(enemy) and enemy:Health() > 0 and not source:HasTeam(enemy) and (gang or source:HasTeam('police') or bgNPC.Combat.IsFighting(enemy)) then enemies[#enemies + 1] = enemy end
  end

  if #enemies == 0 then return end
  local nearby = gang and bgNPC.Actors.GetAll() or bgNPC.Actors.GetInRadius(npc:GetPos(), RADIUS)
  for _, other in ipairs(nearby) do
    -- an officer in a car takes the enemy too: it steps out or fires from the car (modules/dv/sv_move_to_target.lua)
    if other ~= source and other:IsAlive() and (gang or not other:InVehicle() or other:HasTeam('police')) and other:HasTeam(source) then
      local missing
      for _, enemy in ipairs(enemies) do
        local memory = source.enemy_last_position and source.enemy_last_position[enemy]
        local newer = memory and (not other.enemy_last_position or not other.enemy_last_position[enemy] or (source.enemy_last_seen and source.enemy_last_seen[enemy] or 0) > (other.enemy_last_seen and other.enemy_last_seen[enemy] or 0))
        if (not other:HasEnemy(enemy) or newer or (gang and other:EqualStateGroup('calm'))) and not other:HasTeam(enemy) then
          missing = missing or {}
          missing[#missing + 1] = enemy
        end
      end

      -- the trace only for those who have something to learn
      if missing and bgNPC.Vision.HasLineOfSight(other:GetNPC(), npc, 'share') then
        for _, enemy in ipairs(missing) do
          if gang then
            other:AddEnemy(enemy)
            if bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(other, 'share', enemy, nil, npc, other:HasEnemy(enemy)) end
            -- AddEnemy may refuse an enemy protected by an arrest or another gameplay hook.
            if other:HasEnemy(enemy) and other:EqualStateGroup('calm') then
              other:RemoveAllTargets()
              other:SetState(other:IsWanted() and 'retreat' or 'defense')
            end
          else
            Warn(other, enemy, npc)
          end

          other:ShareEnemyMemory(source, enemy)
        end
      end
    end
  end
end

-- A calm actor that sees a scared teammate and, itself, that teammate's enemy takes the enemy too.
-- It must see both: a panic never runs further than the eyes of the witness.
-- Only fear/flight from a threat counts; the scan starts from scared actors near a player, not from every actor.
local FEAR_STATES = {'fear', 'run_from_danger', 'dyspnea_danger'}
local PLAYER_RADIUS = 2500
local function NearPlayer(pos)
  for _, ply in ipairs(player.GetHumans()) do
    if ply:Alive() and ply:GetPos():DistToSqr(pos) <= PLAYER_RADIUS ^ 2 then return true end
  end
  return false
end

local function Witness(scared)
  local scared_npc = scared:GetNPC()
  if not scared:IsAlive() or scared:HasNoEnemies() or not scared:HasState(FEAR_STATES) or not NearPlayer(scared_npc:GetPos()) then return end
  for _, observer in ipairs(bgNPC.Actors.GetInRadius(scared_npc:GetPos(), RADIUS)) do
    local npc = observer:GetNPC()
    if observer ~= scared and observer:IsAlive() and not observer:InVehicle() and observer:EqualStateGroup('calm') and observer:HasTeam(scared) and bgNPC.Vision.HasLineOfSight(npc, scared_npc, 'share') then
      for i = 1, scared.enemies_count do
        local enemy = scared.enemies[i]
        if IsValid(enemy) and enemy:Health() > 0 and not observer:HasEnemy(enemy) and not observer:HasTeam(enemy) and npc:GetPos():DistToSqr(enemy:GetPos()) <= RADIUS ^ 2 and bgNPC.Vision.HasLineOfSight(npc, enemy, 'share') then
          Warn(observer, enemy, scared_npc)
          if not observer:EqualStateGroup('calm') then break end
        end
      end
    end
  end
end

timer.Create('BGN_EnemySharing', 1, 0, function()
  if bgNPC.Modes.IsPeaceful() then return end
  local period = cvar_period:GetFloat()
  if period <= 0 or (bgNPC.enemy_share_next or 0) > CurTime() then return end
  bgNPC.enemy_share_next = CurTime() + period
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    if CanShare(actor) then Share(actor) end
    Witness(actor)
  end
end)
