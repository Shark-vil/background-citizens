--[[
	Actors and cars (Decent Vehicle); the state go_to_police_car does the walk and the boarding.
	- Back to the car: an actor who left a car gets back in once the player has run off (police that drove up
	  and got out, a scared driver that calmed down). Only an empty car it may take (VEHICLE:CanBoard: the one it
	  left or one of its group, never someone else's residents car).
	- Carjacking: a bandit on the run takes a car near it: an empty one, or it throws the driver out (VEHICLE:CanSeize).
	The fight (sv_defense.lua) also sends actors to a car when their enemy drives off.
--]]

local PERIOD = 2
local CAR_RADIUS = 1000     -- actors this close to a car look at it
local PLAYER_FAR = 1500     -- back to the car: every player and every enemy of the actor is at least this far
local CARJACK_RADIUS = 700
local CARJACK_CHANCE = 35   -- per check, for each bandit on the run near a car
-- states it may leave for its car: walking around or a fight with nobody near
local RETURN_FROM = { walk = true, idle = true, defense = true, fear = true, retreat = true, run_from_danger = true }
local ON_THE_RUN = { retreat = true, fear = true, run_from_danger = true }

local function IsAnyoneNear(actor, pos)
	local far_sqr = PLAYER_FAR * PLAYER_FAR
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and ply:GetPos():DistToSqr(pos) < far_sqr then return true end
	end
	for _, enemy in ipairs(actor.enemies) do
		if IsValid(enemy) and enemy:GetPos():DistToSqr(pos) < far_sqr then return true end
	end
	return false
end

local function CanUseCar(actor)
	return actor:IsAlive() and not actor:InVehicle() and actor.mechanics.use_vehicle
end

timer.Create('BGN_ReturnToVehicle', PERIOD, 0, function()
	if not DecentVehicleDestination or #bgNPC.DVCars == 0 then return end

	for _, vehicle_provider in ipairs(bgNPC.DVCars) do
		local car = vehicle_provider:GetVehicle()
		if not IsValid(car) then continue end
		local car_pos = car:GetPos()

		if not vehicle_provider:GetDriver() then
			for _, actor in ipairs(bgNPC.Actors.GetInRadius(car_pos, CAR_RADIUS)) do
				if CanUseCar(actor) and RETURN_FROM[actor:GetState()] and vehicle_provider:CanBoard(actor)
					and not IsAnyoneNear(actor, actor:GetNPC():GetPos())
				then
					actor:SetState('go_to_police_car')
				end
			end
		end

		for _, actor in ipairs(bgNPC.Actors.GetInRadius(car_pos, CARJACK_RADIUS)) do
			local state = actor:GetState()
			if CanUseCar(actor) and ON_THE_RUN[state] and actor:HasTeam('bandits')
				and vehicle_provider:CanSeize(actor) and bgNPC.Util.Chance(CARJACK_CHANCE)
			then
				-- keeps running once inside
				actor:SetState('go_to_police_car', { seize = true, after_state = state })
			end
		end
	end
end)
