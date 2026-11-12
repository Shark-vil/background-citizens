--[[
	The single actor update loop (replaces the old state machine, think, movement and enemy tasks).

	Each actor has a level of detail, recomputed every LOD_PERIOD seconds:
		near     - close to a player or in view: brain every NEAR_PERIOD
		far      - not seen, farther than "bgn_lod_near_radius": brain every FAR_PERIOD
		dormant  - farther than "bgn_disable_logic_radius" and not seen, unarmed, not in a vehicle:
		           alternating engine/brain/movement pauses and active windows
	Movement continues during active windows (it throttles itself).
--]]
local Actors = bgNPC.Actors
local LOD_NEAR, LOD_FAR, LOD_DORMANT = 1, 2, 3
local PERIODS = {
  [LOD_NEAR] = 0.2,
  [LOD_FAR] = 1,
  [LOD_DORMANT] = 0.2
}

local MOVEMENT_PERIODS = {
  [LOD_NEAR] = 0.1,
  [LOD_FAR] = 0.25,
  [LOD_DORMANT] = 0.25
}

local LOD_PERIOD = 1
local ENEMIES_PERIOD = 1
local TARGETS_PERIOD = 5
local PATH_REBUILD_PERIOD = 10
local VEHICLE_PATH_REBUILD_PERIOD = 5
local cvar_near_radius = CreateConVar('bgn_lod_near_radius', '2500', {FCVAR_ARCHIVE}, 'Background NPCs: actors closer than this to a player get full updates', 0)
local cvar_dormant_radius = GetConVar('bgn_disable_logic_radius')
local pause_time = CreateConVar('bgn_logic_pause', '2', {FCVAR_ARCHIVE}, 'Seconds paused for distant unseen actors; 0 disables pauses', 0, 30)
local active_time = CreateConVar('bgn_logic_active', '1', {FCVAR_ARCHIVE}, 'Seconds active between distant actor pauses', 0.1, 30)
local stagger = CreateConVar('bgn_logic_stagger', '0.25', {FCVAR_ARCHIVE}, 'Cycle phase offset per actor in seconds', 0, 10)
local function SetPaused(actor, paused)
  if actor.logic_paused == paused and actor.logic_pause_body == actor.body then return end
  actor.logic_paused, actor.logic_pause_body = paused, actor.body
  if actor.body and not actor:InVehicle() then actor.body:SetThinkEnabled(not paused) end
  if not paused then actor.next_brain = 0 end
end

bgNPC.LOD = {
  NEAR = LOD_NEAR,
  FAR = LOD_FAR,
  DORMANT = LOD_DORMANT
}

local function ComputeLOD(actor, players)
  local pos = actor:GetPos()
  local near_sqr = cvar_near_radius:GetFloat() ^ 2
  local dormant_radius = cvar_dormant_radius and cvar_dormant_radius:GetFloat() or 0
  local dormant_sqr = dormant_radius > 0 and dormant_radius ^ 2 or math.huge
  local min_dist = math.huge
  for i = 1, #players do
    local ply = players[i]
    if IsValid(ply) then
      local dist = pos:DistToSqr(ply:GetPos())
      if dist < min_dist then min_dist = dist end
      if dist <= near_sqr or bgNPC.Util.IsInView(ply, pos) then return LOD_NEAR end
    end
  end

  if min_dist > dormant_sqr and not actor:InVehicle() and not actor:HasActiveWeapon() then return LOD_DORMANT end
  return LOD_FAR
end

local function SetLOD(actor, lod)
  if actor.lod == lod then return end
  actor.lod = lod
  if lod ~= LOD_DORMANT then SetPaused(actor, false) end
  hook.Run('BGN_ActorLODChanged', actor, lod)
end

local function RebuildFollowPath(actor, now)
  local target = actor.walkTarget
  if not IsValid(target) or actor.walkUpdatePathDelay > now then return end
  if actor:InVehicle() then
    actor:WalkToTarget(target)
    actor.walkUpdatePathDelay = now + VEHICLE_PATH_REBUILD_PERIOD
    return
  end

  local path = bgNPC.Points.FindPath(actor:GetPos(), target:GetPos(), nil, actor.pathType, actor)
  if #path ~= 0 then actor.walkPath = path end
  actor.walkUpdatePathDelay = now + PATH_REBUILD_PERIOD
end

local function UpdateActor(actor, now, players)
  if not IsValid(actor:GetNPC()) then return end
  if actor:HasState('knocked_down') then
    actor:CallStateAction(nil, 'update', actor:GetState(), actor:GetStateData())
    return
  end

  if (actor.next_lod or 0) <= now then
    actor.next_lod = now + LOD_PERIOD
    SetLOD(actor, ComputeLOD(actor, players))
  end

  local lod = actor.lod or LOD_NEAR
  local pause = math.max(0, pause_time:GetFloat())
  local duration = math.max(0.1, active_time:GetFloat())
  -- Stable phases survive list reordering/removal; wraps intentionally share slots in large crowds.
  local phase = (now - actor.uid * stagger:GetFloat()) % (pause + duration)
  SetPaused(actor, lod == LOD_DORMANT and pause > 0 and phase >= duration)
  if (actor.next_enemies or 0) <= now then
    actor.next_enemies = now + ENEMIES_PERIOD
    actor:EnemiesRecalculate()
  end

  if (actor.next_targets or 0) <= now then
    actor.next_targets = now + TARGETS_PERIOD
    actor:RecalculationTargets()
  end

  -- Node arrival radius is 150 units, so a walker covers at most ~50 units between movement updates.
  if not actor.logic_paused and (actor.next_movement or 0) <= now then
    actor.next_movement = now + MOVEMENT_PERIODS[lod]
    RebuildFollowPath(actor, now)
    actor:UpdateMovement()
  end

  if not actor.logic_paused and (actor.next_brain or 0) <= now and actor.start_think and actor.brain then
    actor.next_brain = now + PERIODS[lod]
    actor.brain:Update()
  end
end

bgNPC.Tasks.Add('BGN_ActorUpdate', function(yield, wait, budget)
  while true do
    local actors = Actors.GetAll()
    local players = player.GetAll()
    local now = CurTime()
    -- Iterate over a snapshot: actors may be removed while updating.
    local snapshot = {}
    for i = 1, #actors do
      snapshot[i] = actors[i]
    end

    for i = 1, #snapshot do
      local actor = snapshot[i]
      if actor:IsAlive() then
        local ok, err = pcall(UpdateActor, actor, now, players)
        if not ok then ErrorNoHalt('[Background NPCs] Actor update error: ' .. tostring(err) .. '\n') end
      end

      budget()
    end

    yield()
  end
end)

-- Wakes a dormant actor right away (it was attacked, became an enemy, ...).
function Actors.WakeUp(actor)
  actor.next_lod = CurTime() + 1
  actor.next_brain, actor.next_movement = 0, 0
  SetLOD(actor, LOD_NEAR)
end

hook.Add('BGN_AddActorEnemy', 'BGN_LOD_WakeUpOnEnemy', function(actor) if actor.lod == LOD_DORMANT then Actors.WakeUp(actor) end end)
hook.Add('EntityTakeDamage', 'BGN_LOD_WakeUpOnDamage', function(target)
  local actor = Actors.Get(target)
  if actor and actor.lod == LOD_DORMANT then Actors.WakeUp(actor) end
end)
