local Assert = bgNPC.Assert
local Vision = bgNPC.Vision
local Actors = bgNPC.Actors
local table_HasValueBySeq = bgNPC.Table.HasValue
--

local trace_data = {}

-- @return entity|nil car, entity|nil its parent (a seat of simfphys/Glide/LVS sits on the car body)
local function CarOf(ent)
	local car
	if ent:IsPlayer() then
		car = ent:GetVehicle()
	else
		local actor = Actors.Get(ent)
		car = actor and actor:GetVehicle()
	end
	if not IsValid(car) then return end
	local parent = car:GetParent()
	return car, IsValid(parent) and parent or nil
end

-- Checks a direct line of sight from the watcher's eyes to the entity's center.
-- A car the entity sits in counts as the entity.
-- @return boolean visible, entity hit entity
function Vision.HasLineOfSight(watcher, ent)
	if not IsValid(watcher) or watcher:Health() <= 0 then return false end
	if not IsValid(ent) or ent:Health() <= 0 then return false end

	-- a NextBot has no view offset, its EyePos is at the feet and low cover would block the view
	trace_data.start = watcher.BGN_EyePos and watcher:BGN_EyePos() or watcher:EyePos()
	trace_data.endpos = ent:WorldSpaceCenter()
	local watcher_car, watcher_parent = CarOf(watcher)
	trace_data.filter = watcher_car and { watcher, watcher_car, watcher_parent or watcher_car, watcher.Seat } or watcher

	local tr = util.TraceLine(trace_data)
	local hit = tr.Entity
	if not tr.Hit then return false, hit end
	if hit == ent then return true, hit end
	local target_car, target_parent = CarOf(ent)
	return target_car ~= nil and (hit == target_car or hit == target_parent), hit
end

-- Checks whether the position is inside the NPC's field of view.
-- NextBots and non-NPC entities always "see" in all directions.
-- @param fov number|nil half-angle of the view cone in degrees (default 90)
function Vision.NPCCanSeePos(ent, pos, fov)
	Assert.Arg(2, pos, 'vector', 'bgNPC.Vision.NPCCanSeePos')
	Assert.Arg(3, fov, 'number|nil', 'bgNPC.Vision.NPCCanSeePos')

	if not IsValid(ent) or ent:Health() <= 0 then return false end
	if not ent:IsNPC() then return true end

	local direction = pos - ent:GetShootPos()
	local length = direction:Length()
	if length == 0 then return true end

	return ent:GetAimVector():Dot(direction) / length >= math.cos(math.rad(fov or 90))
end

-- Checks whether the position is inside the player's view.
function Vision.PlayerCanSeePos(ply, pos, radius)
	Assert.Arg(2, pos, 'vector', 'bgNPC.Vision.PlayerCanSeePos')
	if not IsValid(ply) then return false end
	return bgNPC.Util.IsInView(ply, pos, radius)
end

local function ActorSees(actor, ent)
	if not actor or not actor:IsAlive() then return false end
	local npc = actor:GetNPC()
	return IsValid(npc) and bgNPC.Util.CanSeeEntity(npc, ent, true)
end

-- Checks whether any actor sees the entity.
-- @param exclude actor|table|nil actor or list of actors to skip
-- @return boolean, actor|nil
function Vision.AnyActorSees(ent, exclude)
	if not IsValid(ent) then return false end

	if istable(exclude) and exclude.isBgnClass then exclude = { exclude } end
	local has_exclude = istable(exclude) and #exclude ~= 0

	local actors = Actors.GetAll()
	for i = 1, #actors do
		local actor = actors[i]
		if not (has_exclude and table_HasValueBySeq(exclude, actor)) and ActorSees(actor, ent) then
			return true, actor
		end
	end

	return false
end

-- Returns all actors that see the entity.
-- @return boolean, table
function Vision.ActorsThatSee(ent)
	if not IsValid(ent) then return false, {} end

	local result = Actors.Filter(function(actor) return ActorSees(actor, ent) end)
	return #result ~= 0, result
end
