local Assert = bgNPC.Assert
local NextId = bgNPC.Util.NextId
local table_HasValueBySeq = bgNPC.Table.HasValue
--

BGN_VEHICLE = {}

local VEHICLE = {}
VEHICLE.__index = VEHICLE
BGN_VEHICLE.VehicleClass = VEHICLE

local DEFAULT_PASSENGERS_MIN = 1
local DEFAULT_PASSENGERS_MAX = 4

local function RandomPassengersLimit()
	return math.random(DEFAULT_PASSENGERS_MIN, DEFAULT_PASSENGERS_MAX)
end

-- Parses the "passengers" part of a custom vehicle group: "3" or "1-4".
local function ParsePassengersLimit(value)
	if not value or value == 'nil' then return RandomPassengersLimit() end

	local range = string.Explode('-', value)
	local min_value, max_value = tonumber(range[1]), tonumber(range[2])

	if min_value and max_value then
		if min_value > max_value then min_value, max_value = max_value, min_value end
		return math.random(min_value, max_value)
	end

	return min_value or RandomPassengersLimit()
end

local function OptionalArg(value, default)
	if not value or value == 'nil' or value == '' then return default end
	return value
end

-- Fills the AI settings of a vehicle from its group.
-- Custom groups are written as "type|ai_class|ai_type|passengers", e.g. "residents|npc_decentvehicle|default|1-3".
local function SetupVehicleGroup(obj, vehicle_type)
	if vehicle_type == 'police' then
		obj.ai_class = 'npc_dvbgn_police'
		obj.ai_type = 'police'
		obj.passengers_limit = RandomPassengersLimit()
		return
	end

	if vehicle_type == 'taxi' then
		obj.ai_class = 'npc_dvtaxi'
		obj.ai_type = 'taxi'
		obj.passengers_limit = 1
		return
	end

	local args = isstring(vehicle_type) and string.Explode('|', vehicle_type) or {}

	if #args > 1 then
		obj.type = OptionalArg(args[1], 'residents')
		obj.ai_class = OptionalArg(args[2], 'npc_decentvehicle')
		obj.ai_type = OptionalArg(args[3], 'default')
		obj.passengers_limit = ParsePassengersLimit(args[4])
	else
		obj.ai_class = 'npc_decentvehicle'
		obj.ai_type = 'default'
		obj.passengers_limit = RandomPassengersLimit()
	end
end

-- Spawns the Decent Vehicle AI that drives the car.
function VEHICLE:Initialize()
	if IsValid(self.ai) then return end

	local vehicle = self.vehicle
	if not IsValid(vehicle) then return end

	local decentvehicle = ents.Create(self.ai_class)
	if not IsValid(decentvehicle) then
		bgNPC.Util.Log('Failed to create vehicle AI "' .. tostring(self.ai_class) .. '"', 'VEHICLE:Initialize')
		return
	end

	local provider = self
	decentvehicle.bgnProvider = provider
	decentvehicle:SetPos(vehicle:GetPos())
	decentvehicle.DontUseSpawnEffect = true
	decentvehicle.DoNotDuplicate = true -- runtime driver AI, not a second actor
	decentvehicle.bgn_type = self.ai_type
	decentvehicle.isBgnActor = true
	function decentvehicle:GetActor() return provider:GetDriver() end

	BGN_VEHICLE:OverrideVehicle(decentvehicle)

	decentvehicle:Spawn()
	decentvehicle:Activate()
	if vehicle.isBgnVehicle and bgNPC.VehicleTraffic then bgNPC.VehicleTraffic.Attach(decentvehicle) end

	self.ai = decentvehicle
end

function VEHICLE:GetDriver()
	if not IsValid(self.ai) then return end
	local driver = self.driver
	if not driver or not driver:IsAlive() then return end
	return driver
end

function VEHICLE:CanUse(actor)
	return IsValid(self.vehicle) and (not self.vehicle.bgnPoliceVehicle or actor:HasTeam('police'))
end

-- Sets the driver actor. nil removes the driver and the AI.
function VEHICLE:SetDriver(actor)
	Assert.Arg(1, actor, 'actor|nil', 'VEHICLE:SetDriver')

	if not actor then
		if IsValid(self.ai) then self.ai:Remove() end
		if self.driver then self:RemovePassenger(self.driver) end
		self.ai = nil
		self.driver = nil
		return
	end

	if self.driver == actor then return IsValid(self.ai) end
	if not self:CanUse(actor) then return false end

	if self.driver then self:RemovePassenger(self.driver) end
	self:RemovePassenger(actor)

	self.driver = actor
	table.insert(self.passengers, actor)

	if IsValid(self.ai) then self.ai:Remove() end
	self.ai = nil
	self:Initialize()
	if not IsValid(self.ai) then
		table.RemoveByValue(self.passengers, actor)
		self.driver = nil
		return false
	end
	return true
end

local function FindFreeSeat(vehicle)
	for index, ent in ipairs(vehicle:GetChildren()) do
		if ent:GetClass() == 'prop_vehicle_prisoner_pod' and not IsValid(ent:GetDriver()) then
			return ent, index
		end
	end
end

-- Seats a passenger actor in a free seat.
-- @return boolean true on success
function VEHICLE:AddPassenger(actor)
	Assert.Arg(1, actor, 'actor', 'VEHICLE:AddPassenger')
	if not self:CanUse(actor) then return false end

	if table_HasValueBySeq(self.passengers, actor) then return false end
	if self.passengers_limit ~= -1 and #self.passengers >= self.passengers_limit then return false end

	local vehicle = self.vehicle
	if not IsValid(vehicle) then return false end

	local seat, seat_index = FindFreeSeat(vehicle)
	if not seat then return false end

	local passenger = ents.Create('npc_decentvehicle_passenger')
	if not IsValid(passenger) then return false end

	passenger.Seat = seat
	passenger.DoNotDuplicate = true
	passenger.SeatIndex = seat_index
	passenger.actor = actor
	passenger.vehicle_provider = self
	passenger.v = vehicle
	passenger:SetPos(vehicle:GetPos())
	passenger:Spawn()
	passenger:Activate()
	if not IsValid(passenger) then return false end

	table.insert(self.passengers_models, passenger)
	table.insert(self.passengers, actor)

	return true, passenger
end

function VEHICLE:RemovePassengerModel(actor)
	for i = #self.passengers_models, 1, -1 do
		local model = self.passengers_models[i]
		if not IsValid(model) then
			table.remove(self.passengers_models, i)
		elseif model.actor == actor then
			model:Remove()
			table.remove(self.passengers_models, i)
		end
	end
end

function VEHICLE:RemovePassenger(actor)
	self:RemovePassengerModel(actor)
	table.RemoveByValue(self.passengers, actor)
end

function VEHICLE:GetPassengers()
	self:PassengersRecalculate()
	return self.passengers
end

function VEHICLE:PassengersRecalculate()
	for i = #self.passengers, 1, -1 do
		local actor = self.passengers[i]
		if not actor or not actor:IsAlive() then
			-- IsAlive may already detach a dead occupant.
			if self.passengers[i] == actor then table.remove(self.passengers, i) end
		end
	end
end

function VEHICLE:GetVehicle()
	return self.vehicle
end

-- An empty car it may take back, or a free passenger seat after its former driver returned.
-- Not someone else's residents car: police and medics are residents too, and citizens keep to their own.
function VEHICLE:CanBoard(actor)
	local vehicle = self.vehicle
	if not self:CanUse(actor) then return false end
	if not IsValid(vehicle) then return false end
	if actor:HasTeam('police') and vehicle:GetMaxHealth() > 0 then
		local health = vehicle.GetCurHealth and vehicle:GetCurHealth() or vehicle:Health()
		if health <= vehicle:GetMaxHealth() * .2 then return false end
	end
	local seated = vehicle:GetDriver()
	if IsValid(seated) and seated ~= self.ai then return false end
	if self:GetDriver() then
		return actor.last_vehicle == self and (self.passengers_limit == -1 or #self.passengers < self.passengers_limit)
			and FindFreeSeat(vehicle) ~= nil
	end
	if actor.last_vehicle == self then return true end
	local group = string.Explode('|', self.type)[1]
	return group ~= 'residents' and actor:HasTeam(group)
end

-- A car of another group the actor may take by force (police confiscation, a gangster carjacking):
-- empty or driven by an actor, never by a player.
function VEHICLE:CanSeize(actor)
	local vehicle = self.vehicle
	if not self:CanUse(actor) then return false end
	if not IsValid(vehicle) or IsValid(vehicle:GetDriver()) then return false end
	local group = string.Explode('|', self.type)[1]
	if group == actor:GetVehicleGroup() then return false end
	-- not from its own people (everyone shares 'residents', so that team doesn't count)
	local driver = self:GetDriver()
	return not (driver and group ~= 'residents' and driver:HasTeam(actor))
end

-- The car now belongs to another group: its AI (police chase, plain driving) follows on the next driver.
function VEHICLE:SetGroup(vehicle_type)
	self.type = vehicle_type or 'residents'
	SetupVehicleGroup(self, vehicle_type)
	if self.type == 'police' then self.vehicle.bgnPoliceVehicle = true end
end

-- Throws everyone out; they are scared of the one who did it.
function VEHICLE:Eject(by_actor)
	local npc = by_actor:GetNPC()
	for _, actor in ipairs(table.Copy(self:GetPassengers())) do
		if actor ~= by_actor and actor:InVehicle() then
			actor:ExitVehicle(true)
			if not actor:HasTeam(by_actor) then
				actor:AddEnemy(npc, 'fear')
				actor:SetState('fear')
			end
		end
	end
end

function VEHICLE:GetVehicleAI()
	return self.ai
end

function VEHICLE:IsValid()
	return IsValid(self.vehicle)
end

function VEHICLE:IsValidAI()
	return IsValid(self.ai)
end

function VEHICLE:IsDestroyed()
	return not self:IsValid()
end

-- Vehicle deletion removes its logical crew; it must never spawn bodies during cleanup.
function VEHICLE:RemoveActors()
	if self.removing then return end
	self.removing = true
	local passengers = {}
	for i = 1, #self.passengers do passengers[i] = self.passengers[i] end
	for i = 1, #passengers do
		passengers[i]:Remove()
	end
	if self.driver then self.driver:Remove() end
end

function VEHICLE:Remove()
	self:RemoveActors()
	local vehicle = self.vehicle
	if IsValid(vehicle) then
		for _, child in ipairs(vehicle:GetChildren()) do
			if IsValid(child) then child:Remove() end
		end

		local parent = vehicle:GetParent()
		if IsValid(parent) then parent:Remove() end

		vehicle:Remove()
	end

	if IsValid(self.ai) then self.ai:Remove() end
end

-- Creates a vehicle provider that connects a car, its AI and the actors inside.
-- @param vehicle_entity entity
-- @param vehicle_type string|nil 'police', 'taxi', a custom group or nil for residents
-- @param actor_type string|nil type of actors that drive this car
-- @return table|nil vehicle provider
function BGN_VEHICLE:Instance(vehicle_entity, vehicle_type, actor_type)
	Assert.Arg(1, vehicle_entity, 'entity', 'BGN_VEHICLE:Instance')
	Assert.Arg(2, vehicle_type, 'string|nil', 'BGN_VEHICLE:Instance')
	Assert.Arg(3, actor_type, 'string|nil', 'BGN_VEHICLE:Instance')

	if not DecentVehicleDestination then return nil end
	if not IsValid(vehicle_entity) then return nil end

	local obj = setmetatable({}, VEHICLE)
	obj.uid = NextId()
	obj.vehicle = vehicle_entity
	obj.type = vehicle_type or 'residents'
	obj.actor_type = actor_type
	obj.ai = nil
	obj.passengers = {}
	obj.passengers_models = {}
	obj.driver = nil
	obj.passengers_limit = -1

	SetupVehicleGroup(obj, vehicle_type)
	-- Keep police ownership even if a later driver changes the provider's group.
	if string.Explode('|', obj.type)[1] == 'police' then vehicle_entity.bgnPoliceVehicle = true end
	if SERVER then
		vehicle_entity:CallOnRemove('BGN_RemoveCrew', function()
			obj:RemoveActors()
		end)
	end

	return obj
end

-- Makes the AI respect per-state speed limits of the driving actor.
function BGN_VEHICLE:OverrideVehicle(decentvehicle)
	local original_GetCurrentMaxSpeed = decentvehicle.GetCurrentMaxSpeed
	if not original_GetCurrentMaxSpeed then return end

	function decentvehicle:GetCurrentMaxSpeed()
		local limit = self.Waypoint and self.Waypoint.SpeedLimit
		if not limit then return original_GetCurrentMaxSpeed(self) end

		local provider = self.bgnProvider or BGN_VEHICLE:GetVehicleProvider(self)
		local actor = provider and provider:GetDriver()
		if not actor then return original_GetCurrentMaxSpeed(self) end

		local state_group = actor:GetStateGroupName()
		if not isstring(state_group) then return original_GetCurrentMaxSpeed(self) end

		local new_limit = limit
		if actor.vehicle_speed and actor.vehicle_speed[state_group] then
			new_limit = actor.vehicle_speed[state_group]
		end

		if actor.vehicle_multiply_speed and actor.vehicle_multiply_speed[state_group] then
			new_limit = new_limit * actor.vehicle_multiply_speed[state_group]
		end

		if new_limit ~= limit then return original_GetCurrentMaxSpeed(self) * new_limit / math.max(limit, 1) end

		return original_GetCurrentMaxSpeed(self)
	end
end

function BGN_VEHICLE:AddToList(vehicle_provider)
	if not vehicle_provider then return -1 end

	local vehicle = vehicle_provider:GetVehicle()
	for i = 1, #bgNPC.DVCars do
		if bgNPC.DVCars[i]:GetVehicle() == vehicle then return -1 end
	end

	return table.insert(bgNPC.DVCars, vehicle_provider)
end

function BGN_VEHICLE:RemoveFromList(vehicle_provider)
	table.RemoveByValue(bgNPC.DVCars, vehicle_provider)
end

-- Finds a provider by its car or by its AI entity.
function BGN_VEHICLE:GetVehicleProvider(vehicle)
	if not IsValid(vehicle) then return nil end

	for i = 1, #bgNPC.DVCars do
		local vehicle_provider = bgNPC.DVCars[i]
		if vehicle_provider.vehicle == vehicle or vehicle_provider.ai == vehicle then
			return vehicle_provider
		end
	end

	return nil
end

if SERVER and not BGN_VEHICLE_GARRYSMOD_METATABLE_OVERRIDE_SUCCESS then
	local VehicleBase = FindMetaTable('Vehicle')
	local original_GetDriver = VehicleBase.GetDriver

	function VehicleBase:GetDriver(...)
		local passenger = self.BGN_DecentVehiclePassenger
		if passenger and IsValid(passenger) then return passenger end
		return original_GetDriver(self, ...)
	end

	BGN_VEHICLE_GARRYSMOD_METATABLE_OVERRIDE_SUCCESS = true
end
