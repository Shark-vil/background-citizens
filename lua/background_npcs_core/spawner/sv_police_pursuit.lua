--
-- A police car that fell behind a wanted player is recreated near the player, out of every player's view.
-- The car is rebuilt (occupants step out, a fresh car is spawned) rather than moved: physics vehicle
-- bases (simfphys wheels, Glide, LVS) break when the chassis is teleported.
local Wanted = bgNPC.Modules.Get('wanted')
local FAR_SQR = 2800 ^ 2
local COOLDOWN = 8
local next_catch_up = {}
bgNPC.PURSUIT_SPAWN_RADIUS = 2200
local function InChase(driver)
  return driver:HasTeam('police') and driver:EnemiesCount() > 0 and not driver:HasState('go_to_police_car')
end

-- Out of every player's view (VehicleIsHidden of the remover is stricter: it also counts cars behind the player as seen).
local function Unseen(vehicle, players)
  local center = vehicle:WorldSpaceCenter()
  for _, ply in ipairs(players) do
    if ply:Alive() and bgNPC.Vision.PlayerCanSeePos(ply, center) then return false end
  end
  return true
end

function bgNPC.IsPursuitCar(provider)
  local driver = provider:GetDriver()
  if not driver or not InChase(driver) then return false end
  for _, wanted in ipairs(Wanted:GetAllWanted()) do
    if IsValid(wanted.target) and wanted.target:IsPlayer() then return true end
  end
  return false
end

local function Recreate(provider, ply)
  local driver = provider:GetDriver()
  local passengers = {}
  for _, actor in ipairs(provider:GetPassengers()) do
    if actor ~= driver then passengers[#passengers + 1] = actor end
  end

  local enemies = {}
  for _, enemy in ipairs(driver.enemies) do
    enemies[#enemies + 1] = enemy
  end

  if not driver:ExitVehicle(true) then -- an obstructed exit: nothing has changed yet
    return
  end

  for _, actor in ipairs(passengers) do
    actor:ExitVehicle(true)
  end

  hook.Run('BGN_DvCarRemoved', provider)
  provider:Remove()
  table.RemoveByValue(bgNPC.DVCars, provider)
  -- shortcut: a failed respawn drops the driver; passengers left on foot are cleaned up by the actor remover.
  if not bgNPC:SpawnVehicleWithActor(driver, true, ply) then
    driver:Remove()
    return
  end

  timer.Simple(1.5, function()
    if not driver:IsAlive() or not driver:InVehicle() then return end
    -- the new body and seat start with a clean slate: without the enemy the new car just drives around
    for _, enemy in ipairs(enemies) do
      if IsValid(enemy) then driver:AddEnemy(enemy) end
    end

    local car = driver:GetVehicle()
    for _, actor in ipairs(passengers) do
      if actor:IsAlive() and not actor:InVehicle() then
        actor:GetNPC():SetPos(car:GetPos())
        actor:EnterVehicle(car)
      end
    end
  end)
end

local function CatchUp(ply, wanted, players)
  local pos, near, best, best_dist = ply:GetPos(), 0, nil, math.huge
  for _, provider in ipairs(bgNPC.DVCars) do
    local driver = provider:IsValid() and provider:GetDriver()
    if driver and InChase(driver) then
      local dist = provider:GetVehicle():GetPos():DistToSqr(pos)
      if dist <= FAR_SQR then
        near = near + 1
      elseif dist < best_dist and Unseen(provider:GetVehicle(), players) then
        best, best_dist = provider, dist
      end
    end
  end

  if not best or near >= 1 + (wanted.level or 1) then return end
  if not bgNPC.FindVehicleSpawnLocation(pos, bgNPC.PURSUIT_SPAWN_RADIUS) then return end
  Recreate(best, ply)
end

timer.Create('BGN_Timer_PolicePursuitCatchUp', 2, 0, function()
  if bgNPC.Modes.IsPeaceful() or not GetConVar('bgn_enable_wanted_mode'):GetBool() or not GetConVar('bgn_enable_dv_support'):GetBool() then return end
  local players, now = player.GetAll(), CurTime()
  for _, wanted in ipairs(Wanted:GetAllWanted()) do
    local ply = wanted.target
    if IsValid(ply) and ply:IsPlayer() and ply:Alive() and (next_catch_up[ply] or 0) <= now then
      next_catch_up[ply] = now + COOLDOWN
      CatchUp(ply, wanted, players)
    end
  end
end)
