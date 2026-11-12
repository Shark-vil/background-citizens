--[[
	Cars run NextBot actors over. A NextBot has no physics object, so a car only stops at its box and the engine
	deals no crush damage (HL2 NPCs get it). Every moving car looks for NextBots in its box and in front of it.
	Cars: driven by players, and Decent Vehicle cars of the actors.
--]]
local PERIOD = 0.1
local MIN_SPEED = 150 -- units per second; slower just pushes
local DAMAGE_PER_SPEED = 0.25 -- 300 u/s: 50, 500 u/s: 100
local HIT_COOLDOWN = 0.5
local PAD = Vector(16, 16, 8)
local function Hit(bot, vehicle, velocity, speed, now)
  if (bot.bgn_vehicle_hit_next or 0) > now then return end
  bot.bgn_vehicle_hit_next = now + HIT_COOLDOWN
  local driver = vehicle.GetDriver and vehicle:GetDriver()
  local dmg = DamageInfo()
  dmg:SetDamage((speed - MIN_SPEED * 0.5) * DAMAGE_PER_SPEED)
  dmg:SetDamageType(DMG_VEHICLE + DMG_CRUSH)
  -- an actor's car: the car itself, Combat.ResolveVehicleAttacker finds the driving actor (GetDriver is its model)
  dmg:SetAttacker(IsValid(driver) and driver:IsPlayer() and driver or vehicle)
  dmg:SetInflictor(vehicle)
  dmg:SetDamageForce(velocity * 60)
  dmg:SetDamagePosition(bot:WorldSpaceCenter())
  bot:TakeDamageInfo(dmg)
  if bot:Health() > 0 and bot.loco then
    if GetConVar('bgn_nextbot_jump'):GetBool() then bot.loco:Jump() end
    bot.loco:SetVelocity(velocity * 0.8 + Vector(0, 0, 200))
  end
end

local function CheckVehicle(vehicle, now)
  if not IsValid(vehicle) then return end
  local velocity = vehicle:GetVelocity()
  local speed = velocity:Length()
  if speed < MIN_SPEED then return end
  local mins, maxs = vehicle:WorldSpaceAABB()
  local ahead = velocity * PERIOD
  mins = mins - PAD + Vector(math.min(ahead.x, 0), math.min(ahead.y, 0), 0)
  maxs = maxs + PAD + Vector(math.max(ahead.x, 0), math.max(ahead.y, 0), 0)
  for _, ent in ipairs(ents.FindInBox(mins, maxs)) do
    -- not the crew: an actor in a car is a hidden, non-solid NextBot kept at the car's center
    if ent.IsBGNNextBot and ent:Health() > 0 and not ent:GetNoDraw() and ent:GetSolid() ~= SOLID_NONE then Hit(ent, vehicle, velocity, speed, now) end
  end
end

timer.Create('BGN_NextBotVehicleHits', PERIOD, 0, function()
  local now = CurTime()
  local checked = {}
  for _, ply in ipairs(player.GetAll()) do
    if ply:InVehicle() then
      local vehicle = ply:GetVehicle()
      -- a seat of a simfphys / scripted car: the car is its parent
      local car = IsValid(vehicle:GetParent()) and vehicle:GetParent() or vehicle
      if not checked[car] then
        checked[car] = true
        CheckVehicle(car, now)
      end
    end
  end

  for _, vehicle_provider in ipairs(bgNPC.DVCars or {}) do
    local car = vehicle_provider:GetVehicle()
    if IsValid(car) and not checked[car] then
      checked[car] = true
      CheckVehicle(car, now)
    end
  end
end)
