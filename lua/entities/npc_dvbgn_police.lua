if SERVER then util.AddNetworkString('BGN_DvPoliceDebugDrawPath') end
AddCSLuaFile()
ENT.Base = 'npc_decentvehicle'
ENT.Type = 'anim'
ENT.PrintName = 'BGN DV Police'
ENT.DV_Police = true
-- Drives to the driver's enemy (police) or to actor.drive_target_pos (medics) by the shortest way:
-- against the lane direction, across lanes, red lights ignored. Without a target it is a normal DV car.
ENT.Model = {'models/player/police.mdl', 'models/player/police_fem.mdl',}
ENT.EnemyTarget = NULL
ENT.Preference = {
  DoTrace = true, -- Whether or not it does some traces
  GiveWay = true, -- Whether or not it gives way for vehicles with ELS
  GiveWayTime = 5, -- Time to reset the offset for giving way
  GobackDuration = 0.7, -- Duration of going back on stuck
  GobackTime = 10, -- Time to start going back on stuck
  LockVehicle = true, -- Whether or not it allows other players to get in
  LockVehicleDependsOnCVar = false, -- Whether or not LockVehicle depends on CVar
  ShouldGoback = true, -- Whether or not it should go backward on stuck
  StopAtTL = true, -- Whether or not it stops at traffic lights with red sign
  StopEmergency = true, -- Whether or not it stops on crash
  StopEmergencyDuration = 5, -- Duration of stopping on crash
  StopEmergencyDurationDependsOnCVar = true, -- Same as LockVehicle, but for StopEmergencyDuration
  StopInfrontofPerson = true, -- Whether or not it stops when it sees something in front of it
  StopInfrontofPersonDependsOnCVar = true, -- Same as LockVehicle, but for StopInfrontofPerson
  TraceMaxBound = 64, -- Maximum hull size of trace: max = Vector(1, 1, 1) * this value, min = -max
  TraceMinLength = 200, -- Minimum trace length in hammer units
  WaitUntilNext = true, -- Whether or not it waits on WaitUntilNext
}

local _cvar_bgn_debug = GetConVar('bgn_debug')
-- list.Set('NPC', 'npc_dvbgn_police', {
--     Name = ENT.PrintName,
--     Class = 'npc_dvbgn_police',
--     Category = 'GreatZenkakuMan\'s NPCs',
-- })
if CLIENT then
  net.Receive('BGN_DvPoliceDebugDrawPath', function()
    local ent = net.ReadEntity()
    local waypoints = net.ReadTable()
    if IsValid(ent) then ent.WaypointList = waypoints end
  end)

  hook.Add('PostDrawTranslucentRenderables', 'BGN_DvPoliceDebugDrawPath', function()
    if not _cvar_bgn_debug or not _cvar_bgn_debug:GetBool() then return end
    for _, dv in ipairs(ents.FindByClass('npc_dvbgn_police')) do
      -- Отрисовка точек из WaypointList
      if IsValid(dv) and dv.WaypointList then
        for index, waypoint in ipairs(dv.WaypointList) do
          if waypoint and waypoint.Target then
            -- Отрисовка точки
            render.SetColorMaterial()
            if index == 1 then
              render.DrawSphere(waypoint.Target, 10, 8, 8, Color(60, 255, 0))
            else
              render.DrawSphere(waypoint.Target, 10, 8, 8)
            end
          end
        end
      end

      -- Отрисовка пути (линии между точками)
      if IsValid(dv) and dv.WaypointList and #dv.WaypointList > 1 then
        for i = 1, #dv.WaypointList - 1 do
          local startPos = dv.WaypointList[i].Target
          local endPos = dv.WaypointList[i + 1].Target
          if startPos and endPos then
            -- Отрисовка линии между точками пути
            render.SetColorMaterial()
            render.DrawLine(startPos, endPos)
          end
        end
      end
    end
  end)
  return
end

local JUMP_DIST = 600 -- lane changes and crossing to another road part between unlinked waypoints
local EYE = Vector(0, 0, 40)
local graph, graph_size
-- Undirected waypoint graph: DV links both ways plus jumps to nearby waypoints in sight. Built once per waypoint set.
-- shortcut: rebuilt only when the waypoint count changes, an edit that keeps the count keeps the old graph
local function BuildGraph()
  local dvd = DecentVehicleDestination
  local wps = dvd.Waypoints
  local adj, grid = {}, {}
  local function Cell(x, y)
    return math.floor(x / JUMP_DIST) .. ':' .. math.floor(y / JUMP_DIST)
  end

  for id, w in ipairs(wps) do
    adj[id] = adj[id] or {}
    for _, nid in ipairs(w.Neighbors or {}) do
      if wps[nid] then
        adj[id][nid] = true
        adj[nid] = adj[nid] or {}
        adj[nid][id] = true
      end
    end

    local key = Cell(w.Target.x, w.Target.y)
    grid[key] = grid[key] or {}
    table.insert(grid[key], id)
  end

  local jump_sqr = JUMP_DIST * JUMP_DIST
  for id, w in ipairs(wps) do
    local p = w.Target
    for dx = -1, 1 do
      for dy = -1, 1 do
        for _, oid in ipairs(grid[Cell(p.x + dx * JUMP_DIST, p.y + dy * JUMP_DIST)] or {}) do
          if oid > id and not adj[id][oid] and p:DistToSqr(wps[oid].Target) <= jump_sqr and not util.TraceLine({
            start = p + EYE,
            endpos = wps[oid].Target + EYE,
            mask = MASK_SOLID_BRUSHONLY
          }).Hit then
            adj[id][oid] = true
            adj[oid][id] = true
          end
        end
      end
    end
  end
  return adj
end

local function GetCustomNode(self, position, speed)
  return {
    Target = position,
    Neighbors = {},
    SpeedLimit = speed or self.MaxSpeed / 2,
    bgn_custom = true,
  }
end

-- @return boolean nothing but the target (or nothing at all) is on the straight line to it
local function IsVisibleTarget(self, pos, enemy)
  local tr = util.TraceLine({
    start = self:LocalToWorld(self:OBBCenter()),
    endpos = pos + EYE,
    filter = function(ent) return ent ~= self and ent ~= self.v and ent:GetClass() ~= 'prop_vehicle_prisoner_pod' end,
  })

  if not tr.Hit then return true end
  local ent = tr.Entity
  if not IsValid(enemy) or not IsValid(ent) then return false end
  return ent == enemy or (ent:IsVehicle() and ent:GetDriver() == enemy)
end

local function FindPath(self, target_pos, enemy)
  local dvd = DecentVehicleDestination
  self.NextWaypoint = nil
  self.WaypointList = {}
  if IsVisibleTarget(self, target_pos, enemy) then
    self.Waypoint = GetCustomNode(self, target_pos)
    return
  end

  local wps = dvd.Waypoints
  if graph_size ~= #wps then graph, graph_size = BuildGraph(), #wps end
  local _, start_id = dvd.GetNearestWaypoint(self:GetPos())
  local goal, goal_id = dvd.GetNearestWaypoint(target_pos)
  if not start_id or not goal_id then return end
  local goal_pos = goal.Target
  local path = bgNPC.AStar.Search({
    start = start_id,
    is_goal = function(id) return id == goal_id end,
    neighbours = function(id, push)
      local pos = wps[id].Target
      for nid in pairs(graph[id]) do
        push(nid, pos:Distance(wps[nid].Target))
      end
    end,
    heuristic = function(id) return wps[id].Target:Distance(goal_pos) end,
    max_iterations = 3000,
  })

  if not path then return end
  -- DV takes the next point from the end of the list; the start waypoint is skipped, it is usually behind the car
  local list = {GetCustomNode(self, target_pos)}
  for i = #path, 2, -1 do
    local w = wps[path[i]]
    list[#list + 1] = GetCustomNode(self, w.Target, w.SpeedLimit)
  end

  self.Waypoint = table.remove(list)
  self.NextWaypoint = table.remove(list)
  self.WaypointList = list
end

-- @return Vector|nil, Entity|nil where to drive: the point the driver was sent to (an ambulance must not chase
-- the medic's enemy), otherwise the driver's enemy
local function GetTarget(self)
  local provider = self.bgnProvider or BGN_VEHICLE:GetVehicleProvider(self.v)
  local actor = provider and provider:GetDriver()
  if not actor or not actor:IsAlive() then return end
  if actor.drive_target_pos then return actor.drive_target_pos end
  local enemy = actor:GetNearEnemy()
  if IsValid(enemy) and enemy:Health() > 0 then return enemy:GetPos(), enemy end
end

function ENT:CarCollide(data)
  local hitEnt = data.HitEntity
  if not hitEnt:IsVehicle() then return end
  for _, dv in ipairs(ents.FindByClass('npc_dvbgn_police')) do
    if dv.v == hitEnt then return end
  end

  local vehicle_provider = self.bgnProvider or BGN_VEHICLE:GetVehicleProvider(self)
  local actor = vehicle_provider and vehicle_provider:GetDriver()
  if not actor or not actor:IsAlive() or not actor:HasTeam('police') then return end
  local driver
  local enemy_vehicle_provider = BGN_VEHICLE:GetVehicleProvider(hitEnt)
  if enemy_vehicle_provider then
    local driver_actor = enemy_vehicle_provider:GetDriver()
    if driver_actor and driver_actor:IsAlive() and not actor:HasTeam(driver_actor) then driver = driver_actor:GetNPC() end
  else
    local driver_ent = hitEnt:GetDriver()
    if IsValid(driver_ent) and not actor:HasTeam(driver_ent) then driver = driver_ent end
  end

  if IsValid(driver) then
    actor:AddEnemy(driver)
    actor:SetState('defense')
  end
end

function ENT:GetCurrentMaxSpeed()
  if not self.IsTargetExists or not self.Waypoint then return self.BaseClass.GetCurrentMaxSpeed(self) end
  local enemy = self.EnemyTarget
  local trace_ent = self.Trace.Entity
  local limit
  if IsValid(enemy) and (trace_ent == enemy or enemy:IsVehicle() or (enemy:IsPlayer() and enemy:InVehicle() and (trace_ent == enemy:GetVehicle() or trace_ent == enemy:GetVehicle():GetParent()))) then
    limit = self.MaxSpeed
  else
    if self.Prependicular >= .9 then self.TurnWaitDelay = CurTime() + 5 end
    if self.TurnWaitDelay and self.TurnWaitDelay > CurTime() then
      limit = math.Clamp(self.MaxSpeed / 2, 500, 800)
    else
      limit = math.Clamp(self.MaxSpeed / 2, 500, 2500)
    end
  end

  -- only our own path nodes: a DV waypoint is shared by every car
  if self.Waypoint.bgn_custom then self.Waypoint.SpeedLimit = limit end
  return limit
end

function ENT:Think()
  local target_pos, enemy = GetTarget(self)
  self.EnemyTarget = enemy or NULL
  self.UpdateWaypointListDelay = self.UpdateWaypointListDelay or 0
  if target_pos then
    self.TargetSeenAt = CurTime()
    if not self.IsTargetExists then
      self.IsTargetExists = true
      self.Preference.GiveWay = false
      self.Preference.StopAtTL = false
      self.Preference.WaitUntilNext = false
      self:SetELS(true)
      self:SetELSSound(true)
      self.UpdateWaypointListDelay = 0
    end

    if not self.Waypoint or self.UpdateWaypointListDelay < CurTime() then
      FindPath(self, target_pos, enemy)
      if _cvar_bgn_debug:GetBool() then
        net.Start('BGN_DvPoliceDebugDrawPath')
        net.WriteEntity(self)
        net.WriteTable(self.WaypointList)
        net.Broadcast()
      end

      -- a moving target needs fresh paths, close to it more often
      self.UpdateWaypointListDelay = CurTime() + (self:GetPos():DistToSqr(target_pos) < 1000000 and 1 or 3)
    end
    -- a target that blinks out for a moment (a car seat swap, a health read) must not toggle the siren
  elseif self.IsTargetExists and CurTime() - (self.TargetSeenAt or 0) > 3 then
    self.IsTargetExists = false
    self.WaypointList = {}
    self.Waypoint = nil
    self.NextWaypoint = nil
    self.Preference.GiveWay = true
    self.Preference.StopAtTL = true
    self.Preference.WaitUntilNext = true
    self:SetELS(false)
    self:SetELSSound(false)
  end
  return self.BaseClass.Think(self)
end
