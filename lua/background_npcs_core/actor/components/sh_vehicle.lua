local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
--

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------
local function ResolveVehicleGroup(actor)
	local vehicle_group = actor.data.vehicle_group
	if vehicle_group then return vehicle_group end
	if actor:HasTeam('police') then return 'police' end
	if actor:HasTeam('taxi') then return 'taxi' end
	return nil
end

function Actor:EnterVehicle(vehicle)
	Assert.Arg(1, vehicle, 'entity', 'ACTOR:EnterVehicle')

	if not self.mechanics.use_vehicle then return end
	if not DecentVehicleDestination then return end
	if not IsValid(vehicle) or not vehicle:IsVehicle() then return end

	local vehicle_provider = BGN_VEHICLE:GetVehicleProvider(vehicle)
	if not vehicle_provider then
		vehicle_provider = BGN_VEHICLE:Instance(vehicle, ResolveVehicleGroup(self), self:GetType())
		if not vehicle_provider then return end
		BGN_VEHICLE:AddToList(vehicle_provider)
	end

	local npc = self.npc

	bgNPC.Util.EntityTimer(vehicle, 'bgn_actor_enter_vehicle', 0.5, 1, function(self_vehicle)
		if not IsValid(self_vehicle) or not self:IsAlive() then return end

		if not vehicle_provider:GetDriver() then
			vehicle_provider:SetDriver(self)
		elseif not vehicle_provider:AddPassenger(self) then
			return
		end

		self.eternal = true
		self.vehicle = vehicle_provider
		self.walkUpdatePathDelay = 0

		-- Not parented: a child is sent to clients with its parent even when nodraw, and then it showed up
		-- T-posed or with its animation copy stretched to the world origin. A nodraw entity without a parent is
		-- not sent at all; the actor update keeps it at the car (Actor:FollowVehicle).
		bgNPC.Animator.Stop(npc)
		npc:SetNoDraw(true)
		npc:SetNW2Bool('bgn_vehicle_entered', true)
		npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
		npc:SetPos(self_vehicle:GetPos())
		npc:AddEFlags(EFL_NO_THINK_FUNCTION)

		hook.Run('BGN_OnEnterVehicle', self, vehicle_provider)
	end)
end

local EXIT_TRACE_OFFSET = Vector(0, 0, 500)
local EXIT_FLOOR_OFFSET = Vector(0, 0, 15)

local function FindVehicleExitPos(vehicle, npc)
	local min, max = vehicle:GetModelBounds()
	local side_dist = min:Distance(max) / 2
	local pos = vehicle:GetPos()
	local forward, right, up = vehicle:GetForward(), vehicle:GetRight(), vehicle:GetUp()
	local side = bgNPC.Util.Chance(50) and -side_dist or side_dist
	local exit_pos = pos + up * 50

	for _ = 1, 4 do
		exit_pos = pos + right * side + forward * math.random(-100, 100) + up * 50

		local tr = util.TraceLine({
			start = exit_pos,
			endpos = exit_pos - EXIT_TRACE_OFFSET,
			filter = npc,
		})

		if tr.Hit then exit_pos = tr.HitPos + EXIT_FLOOR_OFFSET end

		if util.IsInWorld(exit_pos) and #ents.FindInSphere(exit_pos, 15) <= 2 then
			break
		end
	end

	return exit_pos
end

function Actor:ExitVehicle()
	if not self.mechanics.use_vehicle then return end
	if not DecentVehicleDestination then return end

	local vehicle_provider = self.vehicle
	local npc = self.npc

	if vehicle_provider and vehicle_provider:IsValid() and IsValid(npc) then
		hook.Run('BGN_OnExitVehicle', self, vehicle_provider)

		npc:SetNW2Bool('bgn_vehicle_entered', false)
		npc:SetPos(FindVehicleExitPos(vehicle_provider:GetVehicle(), npc))
		npc:SetAngles(Angle(0, npc:GetAngles().y, 0))
		npc:SetCollisionGroup(self.collision_group)
		npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		npc:PhysWake()
		npc:SetNoDraw(false)
		self:DropToFloor()
	end

	if vehicle_provider then
		if vehicle_provider.driver == self then
			vehicle_provider:SetDriver(nil)
		else
			vehicle_provider:RemovePassenger(self)
		end
	end

	self.eternal = false
	self.vehicle = nil
	self.vehicle_data = {}
end

-- Keeps the hidden entity of an actor in a car at the car (it is not parented, see EnterVehicle).
function Actor:FollowVehicle()
	local vehicle = self:GetVehicle()
	if IsValid(vehicle) and IsValid(self.npc) then self.npc:SetPos(vehicle:GetPos()) end
end

function Actor:InVehicle()
	if SERVER then
		return self.vehicle ~= nil and self.vehicle:IsValid()
	end
	return IsValid(self.npc) and self.npc:GetNW2Bool('bgn_vehicle_entered', false)
end

function Actor:GetVehicle()
	if not self.vehicle or not self:InVehicle() then return nil end
	return self.vehicle:GetVehicle()
end

function Actor:GetVehicleAI()
	if not self.vehicle or not self:InVehicle() then return nil end
	return self.vehicle:GetVehicleAI()
end
