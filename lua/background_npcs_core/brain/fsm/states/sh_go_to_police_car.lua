--[[
	Runs to the nearest car the actor may take and gets in. The name stays for compatibility; it is not police only.
	- A car it may board (VEHICLE:CanBoard): the one it left or an empty one of its group.
	- data.seize: when there is none, a car of another group (VEHICLE:CanSeize): the police confiscate it, a gangster
	  carjacks it. Whoever sits inside is thrown out (VEHICLE:Eject) and the car joins the actor's group.
	- data.after_state: the state once inside (default: defense with enemies, walk without).
	Started by the fight when the enemy drives (sv_defense.lua), and by modules/dv/sv_return_to_vehicle.lua.
--]]

local MAX_CAR_DIST_SQR = 1000 ^ 2
local ENTER_DIST_SQR = 500 ^ 2  -- the car is within reach
local SEIZE_DIST_SQR = 250 ^ 2  -- at the door: close enough to pull the driver out

-- @param can string 'CanBoard' or 'CanSeize'
-- @return Entity|nil the nearest car within reach the actor may take that way
local function NearestCar(actor, can)
	local npc_pos = actor:GetNPC():GetPos()
	local best, best_dist

	for _, vehicle_provider in ipairs(bgNPC.DVCars or {}) do
		if vehicle_provider[can](vehicle_provider, actor) then
			local car = vehicle_provider:GetVehicle()
			local dist = npc_pos:DistToSqr(car:GetPos())
			if dist <= MAX_CAR_DIST_SQR and (not best_dist or dist < best_dist) then best, best_dist = car, dist end
		end
	end

	return best
end

local function Seize(actor, car)
	local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(car)
	if not vehicle_provider or not vehicle_provider:CanSeize(actor) then return false end

	if actor:HasTeam('police') then
		actor:Voice('police_seize', 'npc/metropolice/vo/movealong.wav')
	elseif actor:HasTeam('bandits') then
		actor:Voice('gangster_carjack')
	end

	vehicle_provider:Eject(actor)
	vehicle_provider:SetGroup(actor.data.vehicle_group or actor:GetVehicleGroup())
	return true
end

-- the next state may refuse (its enemies come back only in stop): walk then, never stay here
local function Leave(actor, next_state)
	actor:SetState(next_state)
	if actor:HasState('go_to_police_car') then actor:SetState('walk', nil, true) end
end

bgNPC.States.Register('go_to_police_car', 'danger', {
	pre_start = function(actor, state, data)
		-- a car of its own first, a seized one only when there is none near
		local car, seize = NearestCar(actor, 'CanBoard'), false
		if not car and data.seize then car, seize = NearestCar(actor, 'CanSeize'), true end
		if not car then return true end

		local enemies = table.Copy(actor.enemies)
		actor:RemoveAllEnemies()
		actor.mechanics.enemies_controller = false

		local body = actor:GetBody()
		body:SetDisposition(body:GetEnemy(), D_NU)

		return state, {
			car = car,
			seize = seize,
			enemies = enemies,
			after_state = data.after_state,
			timeout = CurTime() + 20
		}
	end,
	update = function(actor, state, data)
		local npc = actor:GetNPC()
		local car = data.car
		if not actor:CheckMoveUpdate('state_go_to_police_cat', 2) then
			return
		end
		-- nothing to fight once inside or given up: back to calm
		local next_state = data.after_state or (#data.enemies ~= 0 and 'defense' or 'walk')
		if not IsValid(car) or data.timeout < CurTime() then
			Leave(actor, next_state)
			return
		end

		actor:WalkToTarget(car, 'run')
		local dist = npc:GetPos():DistToSqr(car:GetPos())
		if data.seize then
			if dist > SEIZE_DIST_SQR then return end
			if not Seize(actor, car) then
				Leave(actor, next_state) -- someone took it first, or a player got in
				return
			end
		elseif dist > ENTER_DIST_SQR then
			return
		end

		actor:EnterVehicle(car)
		Leave(actor, next_state)
	end,
	stop = function(actor, state, data)
		actor.mechanics.enemies_controller = true
		if data.enemies then
			for _, enemy in ipairs(data.enemies) do
				actor:AddEnemy(enemy)
			end
		end
		actor:WalkToTarget(nil)
	end
})
