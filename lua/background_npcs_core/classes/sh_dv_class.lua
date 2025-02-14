local bgNPC = bgNPC
local math_random = math.random
local slib_GetUID = slib.GetUID
local string_Explode = string.Explode
local tonumber = tonumber
local IsValid = IsValid
local ipairs = ipairs
local ents_Create = ents.Create
local table_HasValueBySeq = table.HasValueBySeq
local table_RemoveByValue = table.RemoveByValue
local table_insert = table.insert
local table_remove = table.remove
--
BGN_VEHICLE = {}

function BGN_VEHICLE:Instance(vehicle_entity, vehicle_type, actor_type)
	if not DecentVehicleDestination then return nil end

	local obj = {}
	obj.uid = slib_GetUID()
	obj.vehicle = vehicle_entity
	obj.type = vehicle_type or 'residents'
	obj.actor_type = actor_type
	obj.ai = nil
	obj.passengers = {}
	obj.passengers_models = {}
	obj.driver = nil
	obj.passengers_limit = -1

	if vehicle_type == 'police' then
		obj.ai_class = 'npc_dvbgn_police'
		obj.ai_type = 'police'
		obj.passengers_limit = math_random(1, 4)
	elseif vehicle_type == 'taxi' then
		obj.ai_class = 'npc_dvtaxi'
		obj.ai_type = 'taxi'
		obj.passengers_limit = 1
	else
		local vehicle_type_args = string_Explode('|', vehicle_type)

		if (#vehicle_type_args > 1) then
			obj.type = vehicle_type_args[1] ~= 'nil' and vehicle_type_args[1] or 'residents'
			obj.ai_class = vehicle_type_args[2] ~= 'nil' and vehicle_type_args[2] or 'npc_decentvehicle'
			obj.ai_type = vehicle_type_args[3] ~= 'nil' and vehicle_type_args[3] or 'default'

			if vehicle_type_args[4] and vehicle_type_args[4] ~= 'nil' then
				local passengers_limit = string_Explode('-', vehicle_type_args[4])
				if passengers_limit[1] and passengers_limit[2] then
					obj.passengers_limit = math_random(tonumber(passengers_limit[1]), tonumber(passengers_limit[2]))
				else
					obj.passengers_limit = tonumber(vehicle_type_args[4])
				end
			else
				obj.passengers_limit = math_random(1, 4)
			end
		else
			obj.ai_class = 'npc_decentvehicle'
			obj.ai_type = 'default'
			obj.passengers_limit = math_random(1, 4)
		end
	end

	function obj:Initialize()
		if self.ai or IsValid(self.ai) then return end
		local vehicle = self.vehicle
		local decentvehicle = ents_Create(self.ai_class)
		decentvehicle:SetPos(vehicle:GetPos())
		decentvehicle.DontUseSpawnEffect = true
		decentvehicle.bgn_type = self.ai_type
		BGN_VEHICLE:OverrideVehicle(decentvehicle)
		function decentvehicle:GetActor() return obj:GetDriver() end
		decentvehicle.isBgnActor = true
		decentvehicle:Spawn()
		decentvehicle:Activate()
		self.ai = decentvehicle
	end

	function obj:GetDriver()
		if not IsValid(self.ai) then return end
		if not self.driver or not self.driver:IsAlive() then return end
		return self.driver
	end

	function obj:SetDriver(actor)
		if not actor then
			if IsValid(self.ai) then self.ai:Remove() end
			if self.driver then
				self:RemovePassenger(self.driver)
			end
			self.driver = nil
		elseif not self.driver or actor ~= self.driver then
			self:RemovePassenger(actor)
			self.driver = actor
			self:AddPassenger(actor)
			if IsValid(self.ai) then self.ai:Remove() end
			self.ai = nil
			self:Initialize()
		end
	end

	function obj:AddPassenger(actor)
		if table_HasValueBySeq(self.passengers, actor) then return false end
		if self.passengers_limit ~= -1 and #self.passengers >= self.passengers_limit then return false end

		if self:GetDriver() ~= actor then
			local seats_are_taken = true
			local vehicle = self.vehicle

			for index, ent in ipairs(vehicle:GetChildren()) do
				if ent:GetClass() == 'prop_vehicle_prisoner_pod' and not IsValid(ent:GetDriver()) then
					local passenger = ents_Create('npc_decentvehicle_passenger')
					passenger.Seat = ent
					passenger.SeatIndex = index
					passenger.actor = actor
					passenger.vehicle_provider = self
					passenger.v = vehicle
					-- passenger:SetNWString('actor_uid', actor.uid)
					passenger:SetPos(vehicle:GetPos())
					passenger:Spawn()
					passenger:Activate()
					table_insert(self.passengers_models, passenger)
					seats_are_taken = false
					break
				end
			end

			if seats_are_taken then return false end
		end

		table_insert(self.passengers, actor)
		return true
	end

	function obj:RemovePassengerModel(actor)
		for k = #self.passengers_models, 1, -1 do
			local model = self.passengers_models[k]
			if IsValid(model) and model.actor == actor then
				model:Remove()
				table_remove(self.passengers_models, k)
			end
		end
	end

	function obj:RemovePassenger(actor)
		self:RemovePassengerModel(actor)
		table_RemoveByValue(self.passengers, actor)
	end

	function obj:GetPassengers()
		self:PassengersRecalculate()
		return self.passengers
	end

	function obj:PassengersRecalculate()
		for i = #self.passengers, 1, -1 do
			local actor = self.passengers[i]
			if not actor or not actor:IsAlive() then
				table_remove(self.passengers, i)
			end
		end
	end

	function obj:GetVehicle()
		return self.vehicle
	end

	function obj:GetVehicleAI()
		return self.ai
	end

	function obj:IsValid()
		return self.vehicle and IsValid(self.vehicle)
	end

	function obj:IsValidAI()
		return self.ai and IsValid(self.ai)
	end

	function obj:IsDestroyed()
		return not self:IsValid()
	end

	function obj:Remove()
		local vehicle = self.vehicle
		local decentvehicle = self.ai
		self:PassengersRecalculate()

		for _, actor in ipairs(self.passengers) do
			actor:ExitVehicle()
		end

		if IsValid(vehicle) then
			local child_entity = vehicle:GetChildren()
			local parent_entity = vehicle:GetParent()

			if IsValid(child_entity) then child_entity:Remove() end
			if IsValid(parent_entity) then parent_entity:Remove() end
			if IsValid(vehicle) then vehicle:Remove() end
		end

		if IsValid(decentvehicle) then
			decentvehicle:Remove()
		end
	end

	return obj
end

function BGN_VEHICLE:OverrideVehicle(decentvehicle)
	local original_GetCurrentMaxSpeed = decentvehicle.GetCurrentMaxSpeed

	function decentvehicle:GetCurrentMaxSpeed()
		if self.Waypoint and self.Waypoint.SpeedLimit then
			local limit = self.Waypoint.SpeedLimit
			local provider = BGN_VEHICLE:GetVehicleProvider(self)

			if provider then
				local actor = provider:GetDriver()
				if actor and actor:IsAlive() then
					local state_group = actor:GetStateGroupName()
					if isstring(state_group) then
						local new_limit = limit
						if actor.vehicle_speed and actor.vehicle_speed[state_group] then
							new_limit = actor.vehicle_speed[state_group]
						end

						if actor.vehicle_multiply_speed and actor.vehicle_multiply_speed[state_group] then
							new_limit = new_limit * actor.vehicle_multiply_speed[state_group]
						end

						if new_limit ~= limit then return new_limit end
					end
				end
			end
		end

		return original_GetCurrentMaxSpeed(self)
	end
end

function BGN_VEHICLE:AddToList(vehicle_provider)
	if not vehicle_provider then return -1 end

	for i = 1, #bgNPC.DVCars do
		local other_vehicle_provider = bgNPC.DVCars[i]
		if other_vehicle_provider:GetVehicle() == vehicle_provider:GetVehicle() then return -1 end
	end

	return table_insert(bgNPC.DVCars, vehicle_provider)
end

function BGN_VEHICLE:RemoveFromList(vehicle_provider)
	table_RemoveByValue(bgNPC.DVCars, vehicle_provider)
end

function BGN_VEHICLE:GetVehicleProvider(vehicle)
	for i = 1, #bgNPC.DVCars do
		local vehicle_provider = bgNPC.DVCars[i]
		if vehicle_provider:GetVehicle() == vehicle or vehicle_provider:GetVehicleAI() == vehicle then
			return vehicle_provider
		end
	end

	return nil
end

if SERVER and not BGN_VEHICLE_GARRYSMOD_METATABLE_OVERRIDE_SUCCESS then
	local VehicleBase = FindMetaTable('Vehicle')
	local original_GetDriver = VehicleBase.GetDriver

	function VehicleBase:GetDriver(...)
		if self.BGN_DecentVehiclePassenger and IsValid(self.BGN_DecentVehiclePassenger) then
			return self.BGN_DecentVehiclePassenger
		end

		return original_GetDriver(self, ...)
	end

	BGN_VEHICLE_GARRYSMOD_METATABLE_OVERRIDE_SUCCESS = true
end