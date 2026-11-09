local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
--

local MOVEMENT_FINISHED_DIST_SQR = 150 ^ 2
local MOVEMENT_UPDATE_PERIOD = .5

-- ---------------------------------------------------------------------------
-- Schedules
-- ---------------------------------------------------------------------------
-- OUTDATED: engine schedules are body specific, prefer the body / movement methods.
function Actor:ClearSchedule()
	if self.body then self.body:ClearSchedule() end
end

-- OUTDATED: runs an engine schedule id through the body (NextBots map the common ones).
function Actor:SetSchedule(schedule)
	Assert.Arg(1, schedule, 'number', 'ACTOR:SetSchedule')
	if not self.body or not self:IsAlive() then return end
	if not self:IsSequenceFinished() then return end
	self.body:RunSchedule(schedule)
end

-- True while the body is shooting/reloading and must not be interrupted.
function Actor:IsExecutingCombatSchedule()
	return self.body ~= nil and self.body:IsBusyInCombat()
end

-- ---------------------------------------------------------------------------
-- Movement
-- ---------------------------------------------------------------------------
-- @param move_type string|number|nil 'walk', 'run' or a schedule id
function Actor:SetWalkType(move_type)
	Assert.Arg(1, move_type, 'string|number|nil', 'ACTOR:SetWalkType')

	if isnumber(move_type) then
		self.walkType = move_type
	elseif move_type == 'run' then
		self.walkType = SCHED_FORCED_GO_RUN
	else
		self.walkType = SCHED_FORCED_GO
	end
end

function Actor:StopWalk()
	if self.walkPos or IsValid(self.walkTarget) then
		self:ClearSchedule()
	end

	self.walkTarget = NULL
	self.walkPath = {}
	self.walkPos = nil
	self.walkUpdatePathDelay = 0
	self.pathType = nil
	self.isChase = false
	self:SetWalkType()
end

function Actor:WalkDestinationExists()
	return self.walkPos ~= nil or IsValid(self.walkTarget)
end

local function FinishWalk(actor, pos, move_type)
	return hook.Run('BGN_ActorFinishedWalk', actor, pos, move_type or 'walk')
end

-- Starts following an entity. The path is rebuilt periodically by the movement service.
-- @param target entity|nil target to follow, nil stops walking
function Actor:WalkToTarget(target, move_type, path_type)
	Assert.Arg(1, target, 'entity|nil', 'ACTOR:WalkToTarget')
	Assert.Arg(3, path_type, 'string|nil', 'ACTOR:WalkToTarget')

	if not self.mechanics.movement_controller then return end
	if not IsValid(self.npc) then return end

	if not IsValid(target) then
		self:StopWalk()
		return
	end

	local target_pos = target:GetPos()
	if self.npc:GetPos():DistToSqr(target_pos) <= MOVEMENT_FINISHED_DIST_SQR then
		FinishWalk(self, target_pos, move_type)
		return
	end

	self:SetWalkType(move_type)

	if self.walkTarget == target then return end

	self.pathType = path_type
	self.walkUpdatePathDelay = 0
	self.walkPos = nil
	self.walkPath = {}
	self.walkTarget = target

	if IsValid(self:GetVehicleAI()) then
		self.isChase = true
		self:WalkToPos(target_pos, move_type, path_type)
	end
end

-- Builds a path to the position and starts walking.
-- @param pos vector|node|nil destination, nil stops walking
function Actor:WalkToPos(pos, move_type, path_type)
	Assert.Arg(1, pos, 'vector|node|nil', 'ACTOR:WalkToPos')
	Assert.Arg(3, path_type, 'string|nil', 'ACTOR:WalkToPos')

	if istable(pos) then pos = pos:GetPos() end

	if not self.mechanics.movement_controller then return end

	if pos == nil then
		self:StopWalk()
		return
	end

	local npc = self.npc
	if not IsValid(npc) or not self.body then return end
	if self.walkPos == pos then return end

	local pre_set_result = hook.Run('BGN_PreSetWalkPos', self, pos, move_type, path_type)
	if pre_set_result == false then return end
	if isvector(pre_set_result) then pos = pre_set_result end

	if npc:GetPos():DistToSqr(pos) <= MOVEMENT_FINISHED_DIST_SQR then
		FinishWalk(self, pos, move_type)
		return
	end

	local walk_path = {}

	if not self:InVehicle() then
		if not self.body:IsThinkEnabled() then return end

		walk_path = bgNPC.Points.FindPath(npc:GetPos(), pos, nil, path_type, self)
		if #walk_path == 0 then return end

		self.pathType = path_type
		self:SetWalkType(move_type)
	else
		local decentvehicle = self:GetVehicleAI()
		if not IsValid(decentvehicle) then
			bgNPC.Util.Log('Trying to build a path for a vehicle that doesn\'t exist', 'ACTOR:WalkToPos')
			return
		end

		local route = DecentVehicleDestination.GetRouteVector(decentvehicle:GetPos(), pos)
		if not route then return end

		decentvehicle.WaypointList = route
		decentvehicle.Waypoint = nil
		decentvehicle.NextWaypoint = nil

		for i = 1, #route do
			walk_path[i] = route[i].Target
		end
	end

	if not self.isChase then
		self.walkTarget = NULL
	end

	self.walkPos = pos
	self.walkPath = walk_path

	hook.Run('BGN_ActorSetWalkPath', self, walk_path, pos)
end

-- Returns true once per period for the given tag (false on the first call). Throttles state logic.
function Actor:CheckMoveUpdate(tag, time)
	Assert.Arg(1, tag, 'string', 'ACTOR:CheckMoveUpdate')
	Assert.Arg(2, time, 'number|nil', 'ACTOR:CheckMoveUpdate')

	local timers = self.checkMoveUpdateData or {}
	self.checkMoveUpdateData = timers

	local now = CurTime()
	local next_time = timers[tag]
	if next_time and next_time > now then return false end

	timers[tag] = now + (time or 0)
	return next_time ~= nil
end

function Actor:GetWalkTarget()
	return self.walkTarget
end

function Actor:GetWalkPos()
	return self.walkPos
end

function Actor:Walking()
	return self.body ~= nil and self.body:IsMoving()
end

local function UpdateVehicleMovement(actor, walk_pos)
	local vehicle = actor:GetVehicle()
	if not IsValid(vehicle) then return end
	if vehicle:GetPos():DistToSqr(walk_pos) > MOVEMENT_FINISHED_DIST_SQR then return end

	if not FinishWalk(actor, walk_pos, actor.walkType) then
		actor:WalkToPos(nil)
	end
end

-- A temporary body goal leaves the actor's route/target intact for after the car passes.
function Actor:AvoidDVVehicle()
	if not istable(DecentVehicleDestination) or not GetConVar('bgn_enable_dv_support'):GetBool()
		or self:InVehicle() or self:GetState() == 'go_to_police_car' then return false end
	local body, npc = self.body, self.npc
	if not body or not body:IsThinkEnabled() or body:IsBusyInCombat()
		or self:IsAnimationPlayed() or not self:IsSequenceFinished() then return false end
	if (self.dvAvoidNextCheck or 0) > CurTime() then return self.dvAvoidActive end
	self.dvAvoidNextCheck = CurTime() + MOVEMENT_UPDATE_PERIOD

	local pos = npc:GetPos()
	local car, distance
	for _, ent in ipairs(ents.FindInSphere(pos, 400)) do
		if IsValid(ent.DecentVehicle) then
			local d = ent:NearestPoint(pos):DistToSqr(pos)
			if d < 120 ^ 2 and (not distance or d < distance) then car, distance = ent, d end
		end
	end
	if car ~= self.dvAvoidVehicle then
		self.dvAvoidVehicle = car
		-- 30% ignore traffic for this encounter so pedestrians can still run into the road and get hit.
		self.dvIgnoreVehicle = car ~= nil and bgNPC.Util.Chance(30)
	end
	if not car or self.dvIgnoreVehicle then return false end

	local mins, maxs = npc:GetCollisionBounds()
	local best, clearance
	for _, sign in ipairs({ -1, 1 }) do
		local side = car.DecentVehicle:GetVehicleRight(car) * sign
		side.z = 0
		local target = pos + side:GetNormalized() * 160
		local tr = util.TraceHull({ start = pos + Vector(0, 0, 4), endpos = target + Vector(0, 0, 4),
			mins = mins, maxs = maxs, filter = npc, mask = MASK_NPCSOLID })
		local ground = util.TraceLine({ start = target + Vector(0, 0, 32), endpos = target - Vector(0, 0, 64),
			filter = npc, mask = MASK_NPCSOLID })
		local d = car:NearestPoint(target):DistToSqr(target)
		if not tr.Hit and not tr.StartSolid and ground.Hit and ground.HitNormal.z > .7
			and d > distance and (not clearance or d > clearance) then
			best, clearance = ground.HitPos, d
		end
	end
	if not best then return false end
	body:MoveTo(best, true)
	return true
end

-- Moves the NPC along the current path. Called by the movement service.
function Actor:UpdateMovement()
	if not self.mechanics.movement_controller then return end
	if self.is_animated or not self:IsAlive() then return end
	local avoiding = self:AvoidDVVehicle()
	if self.dvAvoidActive and not avoiding and self.body and not self:InVehicle()
		and not self:IsAnimationPlayed() and self:IsSequenceFinished() and not self.body:IsBusyInCombat() then
		self.body:StopMoving()
	end
	self.dvAvoidActive = avoiding
	if avoiding then return end

	local walk_target = self.walkTarget
	local has_target = IsValid(walk_target)
	local walk_pos = has_target and walk_target:GetPos() or self.walkPos

	if not walk_pos or self:IsAnimationPlayed() then return end

	if self:InVehicle() then
		UpdateVehicleMovement(self, walk_pos)
		return
	end

	local npc = self.npc
	local body = self.body
	if not body then return end

	local npc_pos = npc:GetPos()
	local walk_path = self.walkPath
	local next_position
	local reached_node = false

	if #walk_path ~= 0 then
		next_position = walk_path[1]

		if npc_pos:DistToSqr(next_position) <= MOVEMENT_FINISHED_DIST_SQR then
			table.remove(walk_path, 1)

			if #walk_path == 0 and not has_target then
				if not FinishWalk(self, next_position, self.walkType) then
					self:WalkToPos(nil)
				end
				return
			end

			next_position = walk_path[1]
			reached_node = true
		end
	end

	if has_target then
		-- Close enough to the followed entity, there is no need to push into it.
		if npc_pos:DistToSqr(walk_pos) <= MOVEMENT_FINISHED_DIST_SQR then return end
		-- No path to the target (yet) - let the engine navigate straight to it.
		next_position = next_position or walk_pos
	end

	if not reached_node then
		if not body:IsThinkEnabled() then return end
		if self.waitUpdateMovementDelay > CurTime() then return end
		self.waitUpdateMovementDelay = CurTime() + MOVEMENT_UPDATE_PERIOD
	end

	if body:IsBusyInCombat() or not next_position then return end
	if not self:IsSequenceFinished() then return end

	body:MoveTo(next_position, self.walkType == SCHED_FORCED_GO_RUN)
end

-- ---------------------------------------------------------------------------
-- Movement points
-- ---------------------------------------------------------------------------
local function FindPointByDistanceTo(actor, pos, radius, want_far)
	if not actor:IsAlive() then return nil end

	local points = bgNPC.Points.GetInRadius(actor.npc:GetPos(), radius or 500)
	local result, result_dist

	for i = 1, #points do
		local position = points[i].position
		local dist = position:DistToSqr(pos)
		if not result_dist or (want_far and dist > result_dist) or (not want_far and dist < result_dist) then
			result = position
			result_dist = dist
		end
	end

	return result
end

-- Returns the movement point within the radius that is farthest from pos.
function Actor:GetDistantPointToPoint(pos, radius)
	Assert.Arg(1, pos, 'vector', 'ACTOR:GetDistantPointToPoint')
	Assert.Arg(2, radius, 'number|nil', 'ACTOR:GetDistantPointToPoint')
	return FindPointByDistanceTo(self, pos, radius, true)
end

-- Returns the movement point within the radius that is closest to pos.
function Actor:GetClosestPointToPoint(pos, radius)
	Assert.Arg(1, pos, 'vector', 'ACTOR:GetClosestPointToPoint')
	Assert.Arg(2, radius, 'number|nil', 'ACTOR:GetClosestPointToPoint')
	return FindPointByDistanceTo(self, pos, radius, false)
end

function Actor:GetDistantPointInRadius(radius)
	Assert.Arg(1, radius, 'number|nil', 'ACTOR:GetDistantPointInRadius')
	if not self:IsAlive() then return nil end
	return bgNPC.Points.GetDistantInRadius(self.npc:GetPos(), radius)
end

function Actor:GetClosestPointInRadius(radius)
	Assert.Arg(1, radius, 'number|nil', 'ACTOR:GetClosestPointInRadius')
	if not self:IsAlive() then return nil end
	return bgNPC.Points.GetClosestInRadius(self.npc:GetPos(), radius)
end
