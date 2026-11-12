--[[
	Level of detail for Decent Vehicle drivers. Cars that no player is near or looking at think and scan less often:
	every DV think runs the steering logic, 7 hull traces and a sphere search, which dominates a busy street.
	Cars in a chase, in recovery or fleeing keep the native rate.
--]]
local PERIOD = 1
local NEAR_SQR = 1500 ^ 2
local VIEW_SQR = 3500 ^ 2 -- a car this far away is a speck even when it is in view
local FAR_THINK = 0.05 -- a car at 1500 units/s moves 75 units between thinks, less than a waypoint radius
local FAR = {
  Trace = 0.25,
  GiveWay = 0.5,
  DoLights = 1
}

local cvar_enable = CreateConVar('bgn_vehicle_lod', '1', {FCVAR_ARCHIVE}, 'Background NPCs: unseen cars far from players think and scan their surroundings less often', 0, 1)
local function IsNear(ai, car, players, now)
  if ai.Emergency > now or ai.bgnFlee or (ai.bgnTraffic and ai.bgnTraffic.mode) then return true end
  local pos = car:GetPos()
  for i = 1, #players do
    local ply = players[i]
    if IsValid(ply) then
      local dist = pos:DistToSqr(ply:GetPos())
      if dist <= NEAR_SQR or (dist <= VIEW_SQR and bgNPC.Util.IsInView(ply, pos)) then return true end
    end
  end
  return false
end

-- Wraps the instance think (after the traffic controller's wrapper) so far cars sleep between thinks.
local function Attach(ai)
  local think = ai.Think
  function ai:Think()
    local result = think(self)
    if self.bgnFarLOD then self:NextThink(CurTime() + FAR_THINK) end
    return result
  end

  ai.bgnLodAttached = true
end

timer.Create('BGN_VehicleLOD', PERIOD, 0, function()
  local enabled, now, players = cvar_enable:GetBool(), CurTime(), player.GetAll()
  for _, provider in ipairs(bgNPC.DVCars) do
    local ai, car = provider:GetVehicleAI(), provider:GetVehicle()
    if IsValid(ai) and IsValid(car) then
      local far = enabled and not IsNear(ai, car, players, now)
      if far ~= (ai.bgnFarLOD or false) then
        if far and not ai.bgnLodAttached then Attach(ai) end
        ai.bgnFarLOD = far or nil
        if far then ai.bgnNativeInterval = ai.Interval end
        ai.Interval = far and FAR or ai.bgnNativeInterval
      end
    end
  end
end)

-- A clear trace keeps the car going for 0.1 s; with a longer scan interval that would brake it between scans.
hook.Add('Decent Vehicle: Trace', 'BGN_VehicleLOD', function(ai) if ai.bgnFarLOD and math.abs(ai.StopByTrace - CurTime() - .1) < 1e-4 then ai.StopByTrace = CurTime() + FAR.Trace + .05 end end)
