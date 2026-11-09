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

-- @return string the group of the cars this actor drives: 'police', 'bandits', ... or 'residents'
function Actor:GetVehicleGroup()
	return string.Explode('|', ResolveVehicleGroup(self) or 'residents')[1]
end

local function HideVehicleWeapon(actor)
	local weapon = actor.npc:GetActiveWeapon()
	if not IsValid(weapon) then return end
	actor.vehicle_weapons = actor.vehicle_weapons or {}
	if actor.vehicle_weapons[weapon] == nil then actor.vehicle_weapons[weapon] = weapon:GetNoDraw() end
	weapon:SetNoDraw(true)
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
		if self:InVehicle() then return end

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
		HideVehicleWeapon(self)
		npc:SetNW2Bool('bgn_vehicle_entered', true)
		npc:SetCollisionGroup(COLLISION_GROUP_WORLD)
		-- not solid: inside the car it blocked the car itself (DV saw an obstacle and rocked back and forth)
		self.vehicle_solid = self.vehicle_solid or npc:GetSolid()
		npc:SetSolid(SOLID_NONE)
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

	local hull_mins, hull_maxs = npc:GetCollisionBounds()
	for _ = 1, 8 do
		exit_pos = pos + right * side + forward * math.random(-100, 100) + up * 50

		-- the car is in the filter: the trace used to land on its roof or hood and the actor came out inside the body
		local tr = util.TraceLine({
			start = exit_pos,
			endpos = exit_pos - EXIT_TRACE_OFFSET,
			filter = { npc, vehicle },
		})

		if tr.Hit then exit_pos = tr.HitPos + EXIT_FLOOR_OFFSET end

		-- the spot must be free for the whole body, and not inside the car
		local hull = util.TraceHull({
			start = exit_pos, endpos = exit_pos, mins = hull_mins, maxs = hull_maxs,
			filter = npc, mask = MASK_PLAYERSOLID,
		})
		if util.IsInWorld(exit_pos) and not hull.StartSolid and #ents.FindInSphere(exit_pos, 15) <= 2 then
			break
		end
		side = -side
	end

	return exit_pos
end

function Actor:ShouldExitVehicle()
	if not self:HasTeam('police') or not self.vehicle or not self.vehicle:IsValid() then return true end
	local vehicle = self.vehicle:GetVehicle()
	local max_health = vehicle:GetMaxHealth()
	local health = vehicle.GetCurHealth and vehicle:GetCurHealth() or vehicle:Health()
	if max_health > 0 and health <= max_health * 0.2 then return true end
	for _, ply in ipairs(player.GetAll()) do
		if ply:Alive() and ply:GetPos():DistToSqr(vehicle:GetPos()) <= 800 ^ 2 then return true end
	end
	return false
end

function Actor:ExitVehicle(forced)
	local vehicle_provider = self.vehicle
	local npc = self.npc
	if not vehicle_provider then return end
	if not forced and not self:ShouldExitVehicle() then return end

	if IsValid(npc) then
		hook.Run('BGN_OnExitVehicle', self, vehicle_provider)

		npc:SetNW2Bool('bgn_vehicle_entered', false)
		if vehicle_provider:IsValid() then
			npc:SetPos(FindVehicleExitPos(vehicle_provider:GetVehicle(), npc))
		end
		npc:SetAngles(Angle(0, npc:GetAngles().y, 0))
		npc:SetCollisionGroup(self.collision_group)
		if self.vehicle_solid then npc:SetSolid(self.vehicle_solid) self.vehicle_solid = nil end
		npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
		npc:PhysWake()
		npc:SetNoDraw(false)
		for weapon, nodraw in pairs(self.vehicle_weapons or {}) do
			if IsValid(weapon) then weapon:SetNoDraw(nodraw) end
		end
		self.vehicle_weapons = nil
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
	self.last_vehicle = vehicle_provider -- it may come back to it (go_to_police_car)
	self.vehicle = nil
	self.vehicle_data = {}
	self.__last_player_interaction = CurTime()
end

-- Keeps the hidden entity of an actor in a car at the car (it is not parented, see EnterVehicle).
function Actor:FollowVehicle()
	local vehicle = self:GetVehicle()
	if IsValid(vehicle) and IsValid(self.npc) then
		self.npc:SetPos(vehicle:GetPos())
		HideVehicleWeapon(self)
	end
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

hook.Add('BGN_OnSetActorWeapon', 'BGN_HideVehicleWeapon', function(actor)
	if actor:InVehicle() then HideVehicleWeapon(actor) end
end)
