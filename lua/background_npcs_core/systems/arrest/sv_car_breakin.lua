--[[
	The police break into a car: a player who stands still in a vehicle (within STILL_TOLERANCE) for
	bgn_arrest_car_wait seconds while the police are after them (fighting or arresting, within CALL_RADIUS).
	The officers then hold fire and go to the car (state police_car_breakin); once one is at it the break-in
	takes bgn_arrest_car_time seconds (the client shows a bar shrinking from both sides, cl_car_breakin.lua).
	Driving off STILL_TOLERANCE away cancels it and they fight again; staying ends in an arrest.
--]]

local ArrestModule = bgNPC.Modules.Get('player_arrest')
local cvar_mode = GetConVar('bgn_arrest_mode')
local cvar_wait = GetConVar('bgn_arrest_car_wait')
local cvar_time = GetConVar('bgn_arrest_car_time')

local PERIOD = 0.25
local STILL_TOLERANCE = 64 -- the car may roll this far and still count as standing
local CALL_RADIUS = 2000   -- officers after the player this close come to break in
local AT_CAR_RADIUS = 300  -- an officer this close is breaking in
local GRACE = 1.5          -- officers move: nobody for this long before it starts over

-- Officers after the player within radius of pos (fighting them, arresting them or already breaking in)
local function PoliceAfter(ply, pos, radius)
	local list = {}
	for _, actor in ipairs(bgNPC.Actors.GetInRadius(pos, radius)) do
		if actor:IsAlive() and actor:HasTeam('police') and (actor:HasEnemy(ply) or actor:HasTarget(ply)) then
			list[#list + 1] = actor
		end
	end
	return list
end

local function SetBreakin(ply, start)
	if ply.bgn_breakin_start == start then return end
	ply.bgn_breakin_start = start
	bgNPC.Net.Send('bgn_car_breakin', ply, start or 0, cvar_time:GetFloat())
end

local function Reset(ply)
	ply.bgn_still = nil
	SetBreakin(ply, nil)
end

-- The end of an arrest for a player, as in the arrest state (BGN_PlayerArrest lets DarkRP and others take over)
local function Arrest(ply, actor)
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

timer.Create('BGN_CarBreakin', PERIOD, 0, function()
	local wait = cvar_wait:GetFloat()
	local enabled = wait > 0 and cvar_mode:GetBool()
	local now = CurTime()

	for _, ply in ipairs(player.GetAll()) do
		local vehicle = ply:Alive() and ply:InVehicle() and ply:GetVehicle()
		if not enabled or not IsValid(vehicle) or bgNPC.Combat.IsIgnored(ply) then
			Reset(ply)
			continue
		end

		local car = IsValid(vehicle:GetParent()) and vehicle:GetParent() or vehicle
		local pos = car:GetPos()
		local still = ply.bgn_still

		if not still or still.car ~= car or still.pos:DistToSqr(pos) > STILL_TOLERANCE * STILL_TOLERANCE then
			ply.bgn_still = { car = car, pos = pos, since = now, seen = now }
			SetBreakin(ply, nil)
			continue
		end

		local police = PoliceAfter(ply, pos, CALL_RADIUS)
		if #police ~= 0 then
			still.seen = now
		elseif now - still.seen > GRACE then
			still.since = now -- nobody after the player: the wait starts again when they come
			SetBreakin(ply, nil)
			continue
		end

		if now - still.since < wait then continue end

		-- they stop shooting and come to the car (driving off makes a new still table without "called")
		still.called = true
		for _, actor in ipairs(police) do
			if not actor:HasState('police_car_breakin') then
				actor:SetState('police_car_breakin', { target = ply }, true)
			end
		end

		local at_car
		for _, actor in ipairs(police) do
			if actor:HasState('police_car_breakin') and actor:GetNPC():GetPos():DistToSqr(pos) <= AT_CAR_RADIUS ^ 2 then
				at_car = actor
				break
			end
		end

		if at_car then
			still.at_car = now
			if not ply.bgn_breakin_start then
				SetBreakin(ply, now)
				at_car:Voice('police_seize', 'npc/metropolice/vo/movealong.wav')
			elseif now - ply.bgn_breakin_start >= cvar_time:GetFloat() then
				Arrest(ply, at_car)
			end
		elseif ply.bgn_breakin_start and now - (still.at_car or 0) > GRACE then
			SetBreakin(ply, nil) -- the officer at the car is gone (killed, pushed away): starts over when one comes
		end
	end
end)
