--[[
	The police break into a car: a player who stands still in a vehicle (within STILL_TOLERANCE) for
	bgn_arrest_car_wait seconds while an officer after them is on foot at the car. The break-in takes
	bgn_arrest_car_time seconds (the client shows a bar shrinking from both sides, cl_car_breakin.lua);
	driving off STILL_TOLERANCE away cancels it, staying ends in an arrest.
--]]

local ArrestModule = bgNPC.Modules.Get('player_arrest')
local cvar_mode = GetConVar('bgn_arrest_mode')
local cvar_wait = GetConVar('bgn_arrest_car_wait')
local cvar_time = GetConVar('bgn_arrest_car_time')

local PERIOD = 0.25
local STILL_TOLERANCE = 64 -- the car may roll this far and still count as standing
local POLICE_RADIUS = 300  -- an officer on foot this close to the car
local POLICE_GRACE = 1.5   -- officers move in a fight: gone this long before it starts over

-- An officer on foot at the car who is after the player (fights or arrests them)
local function PoliceAt(ply, car)
	local nearest, nearest_dist
	for _, actor in ipairs(bgNPC.Actors.GetInRadius(car:GetPos(), POLICE_RADIUS)) do
		if actor:IsAlive() and not actor:InVehicle() and actor:HasTeam('police')
			and (actor:HasEnemy(ply) or actor:HasTarget(ply))
		then
			local dist = actor:GetNPC():GetPos():DistToSqr(car:GetPos())
			if not nearest_dist or dist < nearest_dist then nearest, nearest_dist = actor, dist end
		end
	end
	return nearest
end

local function SetBreakin(ply, start)
	if ply.bgn_breakin_start == start then return end
	ply.bgn_breakin_start = start
	bgNPC.Net.Send('bgn_car_breakin', ply, start or 0, cvar_time:GetFloat())
end

-- The end of an arrest for a player, as in the arrest state (BGN_PlayerArrest lets DarkRP and others take over)
local function Arrest(ply, actor)
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
			ply.bgn_still = nil
			SetBreakin(ply, nil)
			continue
		end

		local car = IsValid(vehicle:GetParent()) and vehicle:GetParent() or vehicle
		local pos = car:GetPos()
		local still = ply.bgn_still

		if not still or still.car ~= car or still.pos:DistToSqr(pos) > STILL_TOLERANCE * STILL_TOLERANCE then
			ply.bgn_still = { car = car, pos = pos, since = now }
			SetBreakin(ply, nil)
			continue
		end

		local police = PoliceAt(ply, car)
		if police then
			still.police, still.police_seen = police, now
		elseif now - (still.police_seen or 0) > POLICE_GRACE then
			still.since = now -- nobody at the car: the wait starts again when they come
			SetBreakin(ply, nil)
			continue
		end
		police = police or still.police
		if not police:IsAlive() then continue end

		if now - still.since < wait then continue end

		if not ply.bgn_breakin_start then
			SetBreakin(ply, now)
			police:Voice('police_seize', 'npc/metropolice/vo/movealong.wav')
		elseif now - ply.bgn_breakin_start >= cvar_time:GetFloat() then
			ply.bgn_still = nil
			SetBreakin(ply, nil)
			Arrest(ply, police)
		end
	end
end)
