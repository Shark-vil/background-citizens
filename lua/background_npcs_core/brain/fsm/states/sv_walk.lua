local Chance = bgNPC.Util.Chance
local table_RandomBySeq = bgNPC.Table.Random
local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
local function GetRandomFoundPointDistance()
  local result = 0
  local chance = Chance(30)
  if Chance(30) then
    result = math.random(chance and 100 or 500, 2500)
  else
    result = math.random(chance and 500 or 1000, 2500)
  end
  return math.Clamp(result, 0, cvar_bgn_spawn_radius:GetInt())
end

local function GetRandomDelayForUpdateWalkTarget()
  return CurTime() + math.random(15, 60)
end

local function GetNextMovePosition(actor)
  local npc_pos = actor:GetPos()
  local dist = GetRandomFoundPointDistance()
  local points = bgNPC.Points.GetInRadius(npc_pos, dist, 'walk')
  if not points or #points == 0 then points = bgNPC.Points.GetAll('walk') end
  if not points or #points == 0 then points = bgNPC.Points.GetAll() end
  if not points or #points == 0 then
    local dist_x = math.random(250, 1000)
    local dist_y = math.random(250, 1000)
    if Chance(50) then dist_x = -dist_x end
    if Chance(50) then dist_y = -dist_y end
    return Vector(npc_pos.x + dist_x, npc_pos.y + dist_y, npc_pos.z)
  end

  local node = table_RandomBySeq(points)
  return node.position
end

local function UpdateActorMovementType(actor, data)
  if data.updateMovementTypeDelay > CurTime() then return end
  if data.schedule == 'run' then
    if data.timeToResetRunMovementType < CurTime() then data.schedule = 'walk' end
  elseif Chance(5) then
    data.timeToResetRunMovementType = CurTime() + math.random(5, 30)
    data.schedule = 'run'
  end

  data.updateMovementTypeDelay = CurTime() + 1
end

local function UpdateActorTargetPointAsync(actor, data)
  -- if not data.Dick or data.Dick > CurTime() then
  -- 	local actors = bgNPC.Actors.GetInRadius(actor:GetPos(), 300)
  -- 	if #actors >= 3 then
  -- 		data.updateTargetPointDelay = 0
  -- 		print(1)
  -- 		data.Dick = CurTime() + 10
  -- 	else
  -- 		data.Dick = CurTime() + 1
  -- 	end
  -- end
  if not data.updateTargetPointDelay or data.updateTargetPointDelay > CurTime() then return end
  local position = GetNextMovePosition(actor)
  if not position then return end
  local delay, schedule
  if bgNPC.GangPack then -- a gang walks as a pack
    position, delay, schedule = bgNPC.GangPack.Destination(actor, position)
  end

  if schedule then data.schedule = schedule end
  actor:WalkToPos(position, data.schedule, 'walk')
  data.updateTargetPointDelay = delay and CurTime() + delay or GetRandomDelayForUpdateWalkTarget()
end

bgNPC.States.Register('walk', 'calm', {
  update = function(actor)
    local data = actor:GetStateData()
    data.schedule = data.schedule or 'walk'
    data.timeToResetRunMovementType = data.timeToResetRunMovementType or 0
    data.updateTargetPointDelay = data.updateTargetPointDelay or 0
    data.updateMovementTypeDelay = data.updateMovementTypeDelay or 0
    UpdateActorMovementType(actor, data)
    UpdateActorTargetPointAsync(actor, data)
  end
})

hook.Add('BGN_ActorFinishedWalk', 'BGN_WalkStateUpdatePoint', function(actor)
  if not actor or not actor:IsAlive() or actor:GetState() ~= 'walk' then return end
  local data = actor:GetStateData()
  data.updateMovementTypeDelay = 0
  data.updateTargetPointDelay = 0
end)
