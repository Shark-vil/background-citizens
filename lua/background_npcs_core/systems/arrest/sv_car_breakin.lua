--[[
	The police break into a car: a suspect (a player, or an actor that is not an officer) who stands still in a
	vehicle (within STILL_TOLERANCE) for bgn_arrest_car_wait seconds while the police are after them (fighting or
	arresting, within CALL_RADIUS). The officers then hold fire and go to the car (state police_car_breakin); once one
	is at it the break-in takes bgn_arrest_car_time seconds (a player sees a bar shrinking from both sides,
	cl_car_breakin.lua). Driving off STILL_TOLERANCE away cancels it and they fight again; staying ends in an arrest:
	a player is arrested at once, an actor is pulled out and goes through the usual arrest (ArrestModule:Surrender).
	The progress lives on the suspect's entity (ent.bgn_still); an actor's entity changes when it steps out.
--]]
local ArrestModule = bgNPC.Modules.Get('player_arrest')
local cvar_mode = GetConVar('bgn_arrest_mode')
local cvar_wait = GetConVar('bgn_arrest_car_wait')
local cvar_time = GetConVar('bgn_arrest_car_time')
local PERIOD = 0.25
local STILL_TOLERANCE = 64 -- the car may roll this far and still count as standing
local CALL_RADIUS = 2000 -- officers after the suspect this close come to break in
local AT_CAR_RADIUS = 300 -- an officer this close is breaking in
local GRACE = 1.5 -- officers move: nobody after the suspect for this long before the wait starts over
-- Officers after the suspect within radius of pos (fighting them, arresting them or already breaking in)
local function PoliceAfter(ent, pos, radius)
  local list = {}
  for _, actor in ipairs(bgNPC.Actors.GetInRadius(pos, radius)) do
    if actor:IsAlive() and actor:HasTeam('police') and (actor:HasEnemy(ent) or actor:HasTarget(ent)) then list[#list + 1] = actor end
  end
  return list
end

-- The bar on a player's client: progress (seconds done) and whether it runs now; sent only when that changes.
-- progress nil hides it. Actors have no bar.
local function SetBreakin(ent, progress, running)
  if not ent:IsPlayer() then return end
  -- while it runs the client counts on from the sent progress, so only a change of mode is sent
  local key = progress and (running and 'run' or 'pause') or 'none'
  if (ent.bgn_breakin_shown or 'none') == key then return end
  ent.bgn_breakin_shown = key
  bgNPC.Net.Send('bgn_car_breakin', ent, progress or -1, cvar_time:GetFloat(), running or false)
end

local function Reset(ent)
  ent.bgn_still = nil
  SetBreakin(ent, nil)
end

-- @return entity|nil the car of a suspect whose break-in has been called (police_car_breakin follows it)
function ArrestModule:BreakinCar(ent)
  local still = IsValid(ent) and ent.bgn_still
  return still and still.called and IsValid(still.car) and still.car or nil
end

-- The end of an arrest for a player, as in the arrest state (BGN_PlayerArrest lets DarkRP and others take over)
local function ArrestPlayer(ply, actor)
  Reset(ply) -- first: the officers' state lets go of the player without its car
  ply:ExitVehicle()
  ArrestModule:RemoveTarget(ply)
  actor:Voice('police_arrested')
  if not hook.Run('BGN_PlayerArrest', ply, actor) then
    ply:EmitSound('background_npcs/handcuffs_sound1.mp3')
    ply:ScreenFade(SCREENFADE.IN, Color(0, 0, 0, 255), 1, 3)
    ply:KillSilent()
  end

  for _, other in ipairs(bgNPC.Actors.GetAll()) do
    other:RemoveTarget(ply)
    other:RemoveEnemy(ply)
  end
end

-- An actor is pulled out and gives up to the officer at the car; the arrest state takes it from there
local function ArrestActor(suspect, actor)
  local old = suspect:GetNPC()
  -- the officers stand at the doors, so they do not block it; a wall or a car does: the full bar tries again next tick
  if not suspect:ExitVehicle(true, true) then return end
  Reset(old)
  ArrestModule:RemoveTarget(old)
  ArrestModule:Surrender(suspect, actor)
end

-- @return table list of { ent, car } for every player and non-police actor sitting in a vehicle
local function Suspects()
  local list = {}
  for _, ply in ipairs(player.GetAll()) do
    local vehicle = ply:Alive() and ply:InVehicle() and ply:GetVehicle()
    if IsValid(vehicle) and not bgNPC.Combat.IsIgnored(ply) then
      list[#list + 1] = {
        ent = ply,
        car = IsValid(vehicle:GetParent()) and vehicle:GetParent() or vehicle
      }
    else
      Reset(ply)
    end
  end

  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    local car = actor:IsAlive() and not actor:HasTeam('police') and actor:GetVehicle()
    if IsValid(car) and IsValid(actor:GetNPC()) then
      list[#list + 1] = {
        ent = actor:GetNPC(),
        car = car
      }
    end
  end
  return list
end

timer.Create('BGN_CarBreakin', PERIOD, 0, function()
  local wait = cvar_wait:GetFloat()
  if wait <= 0 or not cvar_mode:GetBool() then
    for _, ply in ipairs(player.GetAll()) do
      Reset(ply)
    end
    return
  end

  local now = CurTime()
  for _, suspect in ipairs(Suspects()) do
    local ent, car = suspect.ent, suspect.car
    local pos = car:GetPos()
    local still = ent.bgn_still
    if not still or still.car ~= car or still.pos:DistToSqr(pos) > STILL_TOLERANCE * STILL_TOLERANCE then
      ent.bgn_still = {
        car = car,
        pos = pos,
        since = now,
        seen = now,
        progress = 0
      }

      SetBreakin(ent, nil)
      continue
    end

    local police = PoliceAfter(ent, pos, CALL_RADIUS)
    if #police ~= 0 then
      still.seen = now
    elseif now - still.seen > GRACE then
      -- nobody after the suspect: the wait starts again when they come, a started break-in keeps its progress
      still.since = now
      if still.progress > 0 then SetBreakin(ent, still.progress, false) end
      continue
    end

    if now - still.since < wait then continue end
    -- they stop shooting and come to the car (driving off makes a new still table without "called")
    still.called = true
    for _, actor in ipairs(police) do
      if not actor:HasState('police_car_breakin') then
        actor:SetState('police_car_breakin', {
          target = ent
        }, true)
      end
    end

    local at_car
    for _, actor in ipairs(police) do
      if actor:HasState('police_car_breakin') and actor:GetNPC():GetPos():DistToSqr(pos) <= AT_CAR_RADIUS ^ 2 then
        at_car = actor
        break
      end
    end

    -- the officer at the car may step away (pushed, a shot to dodge): the bar pauses, it never starts over
    if at_car then
      if still.progress == 0 then at_car:Voice('police_seize', 'npc/metropolice/vo/movealong.wav') end
      still.progress = still.progress + PERIOD
      if still.progress < cvar_time:GetFloat() then
        SetBreakin(ent, still.progress, true)
      elseif ent:IsPlayer() then
        ArrestPlayer(ent, at_car)
      else
        ArrestActor(bgNPC.Actors.Get(ent), at_car)
      end
    elseif still.progress > 0 then
      SetBreakin(ent, still.progress, false)
    end
  end
end)
