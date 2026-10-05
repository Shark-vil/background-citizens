local bgNPC = bgNPC
local Assert = bgNPC.Assert
local math_random = math.random
local slib_GetUID = slib.GetUID
local string_Explode = string.Explode
local tonumber = tonumber
local isstring = isstring
local IsValid = IsValid
local ipairs = ipairs
local setmetatable = setmetatable
local ents_Create = ents.Create
local table_HasValueBySeq = table.HasValueBySeq
local table_RemoveByValue = table.RemoveByValue
local table_insert = table.insert
local table_remove = table.remove
--

BGN_VEHICLE = {}

local VEHICLE = {}
VEHICLE.__index = VEHICLE
BGN_VEHICLE.VehicleClass = VEHICLE

local DEFAULT_PASSENGERS_MIN = 1
local DEFAULT_PASSENGERS_MAX = 4

local function RandomPassengersLimit()
	return math_random(DEFAULT_PASSENGERS_MIN, DEFAULT_PASSENGERS_MAX)
end

-- Parses the "passengers" part of a custom vehicle group: "3" or "1-4".
local function ParsePassengersLimit(value)
	if not value or value == 'nil' then return RandomPassengersLimit() end

	local range = string_Explode('-', value)
	local min_value, max_value = tonumber(range[1]), tonumber(range[2])

	if min_value and max_value then
		if min_value > max_value then min_value, max_value = max_value, min_value end
		return math_random(min_value, max_value)
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

	local args = isstring(vehicle_type) and string_Explode('|', vehicle_type) or {}

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

	local decentvehicle = ents_Create(self.ai_class)
	if not IsValid(decentvehicle) then
		bgNPC.Util.Log('Failed to create vehicle AI "' .. tostring(self.ai_class) .. '"', 'VEHICLE:Initialize')
		return
	end

	local provider = self
	decentvehicle:SetPos(vehicle:GetPos())
	decentvehicle.DontUseSpawnEffect = true
	decentvehicle.bgn_type = self.ai_type
	decentvehicle.isBgnActor = true
	function decentvehicle:GetActor() return provider:GetDriver() end

	BGN_VEHICLE:OverrideVehicle(decentvehicle)

	decentvehicle:Spawn()
	decentvehicle:Activate()

	self.ai = decentvehicle
end

function VEHICLE:GetDriver()
	if not IsValid(self.ai) then return end
	local driver = self.driver
	if not driver or not driver:IsAlive() then return end
	return driver
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

	if self.driver == actor then return end

	if self.driver then self:RemovePassenger(self.driver) end
	self:RemovePassenger(actor)

	self.driver = actor
	table_insert(self.passengers, actor)

	if IsValid(self.ai) then self.ai:Remove() end
	self.ai = nil
	self:Initialize()
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

	if table_HasValueBySeq(self.passengers, actor) then return false end
	if self.passengers_limit ~= -1 and #self.passengers >= self.passengers_limit then return false end

	local vehicle = self.vehicle
	if not IsValid(vehicle) then return false end

	local seat, seat_index = FindFreeSeat(vehicle)
	if not seat then return false end

	local passenger = ents_Create('npc_decentvehicle_passenger')
	if not IsValid(passenger) then return false end

	passenger.Seat = seat
	passenger.SeatIndex = seat_index
	passenger.actor = actor
	passenger.vehicle_provider = self
	passenger.v = vehicle
	passenger:SetPos(vehicle:GetPos())
	passenger:Spawn()
	passenger:Activate()

	table_insert(self.passengers_models, passenger)
	table_insert(self.passengers, actor)

	return true
end

function VEHICLE:RemovePassengerModel(actor)
	for i = #self.passengers_models, 1, -1 do
		local model = self.passengers_models[i]
		if not IsValid(model) then
			table_remove(self.passengers_models, i)
		elseif model.actor == actor then
			model:Remove()
			table_remove(self.passengers_models, i)
		end
	end
end

function VEHICLE:RemovePassenger(actor)
	self:RemovePassengerModel(actor)
	table_RemoveByValue(self.passengers, actor)
end

function VEHICLE:GetPassengers()
	self:PassengersRecalculate()
	return self.passengers
end

function VEHICLE:PassengersRecalculate()
	for i = #self.passengers, 1, -1 do
		local actor = self.passengers[i]
		if not actor or not actor:IsAlive() then
			table_remove(self.passengers, i)
		end
	end
end

function VEHICLE:GetVehicle()
	return self.vehicle
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

-- Drops all passengers out and removes the vehicle with its AI.
function VEHICLE:Remove()
	self:PassengersRecalculate()

	-- ExitVehicle modifies the passengers list, iterate over a copy.
	local passengers = {}
	for i = 1, #self.passengers do passengers[i] = self.passengers[i] end

	for i = 1, #passengers do
		passengers[i]:ExitVehicle()
	end

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
	obj.uid = slib_GetUID()
	obj.vehicle = vehicle_entity
	obj.type = vehicle_type or 'residents'
	obj.actor_type = actor_type
	obj.ai = nil
	obj.passengers = {}
	obj.passengers_models = {}
	obj.driver = nil
	obj.passengers_limit = -1

	SetupVehicleGroup(obj, vehicle_type)

	return obj
end

-- Makes the AI respect per-state speed limits of the driving actor.
function BGN_VEHICLE:OverrideVehicle(decentvehicle)
	local original_GetCurrentMaxSpeed = decentvehicle.GetCurrentMaxSpeed
	if not original_GetCurrentMaxSpeed then return end

	function decentvehicle:GetCurrentMaxSpeed()
		local limit = self.Waypoint and self.Waypoint.SpeedLimit
		if not limit then return original_GetCurrentMaxSpeed(self) end

		local provider = BGN_VEHICLE:GetVehicleProvider(self)
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

		if new_limit ~= limit then return new_limit end

		return original_GetCurrentMaxSpeed(self)
	end
end

function BGN_VEHICLE:AddToList(vehicle_provider)
	if not vehicle_provider then return -1 end

	local vehicle = vehicle_provider:GetVehicle()
	for i = 1, #bgNPC.DVCars do
		if bgNPC.DVCars[i]:GetVehicle() == vehicle then return -1 end
	end

	return table_insert(bgNPC.DVCars, vehicle_provider)
end

function BGN_VEHICLE:RemoveFromList(vehicle_provider)
	table_RemoveByValue(bgNPC.DVCars, vehicle_provider)
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
