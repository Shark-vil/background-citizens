--[[
	Gang members like to walk in a pack, fight or no fight. In the "walk" state a gang member does not pick its own
	destination when a member of the same gang that is walking too is within RADIUS: the one with the lowest entity
	index is the leader and walks where it wants, the others follow the leader itself (a spot SPREAD_MIN-SPREAD_MAX
	units around its current position) at the leader's pace (walk or run), rechecking every FOLLOW_DELAY seconds.
	Used by the walk state (BGN walk destination); actors outside gangs are not touched.
--]]

local GangPack = {}
bgNPC.GangPack = GangPack

local RADIUS = 1500
local FOLLOW_DELAY = 2
local SPREAD_MIN, SPREAD_MAX = 80, 180

local function Leader(actor)
	local npc = actor:GetNPC()
	local gang, leader = actor.data.gang, actor
	for _, other in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), RADIUS)) do
		if other ~= actor and other.data.gang == gang and other:IsAlive() and other:GetState() == 'walk'
			and other:GetNPC():EntIndex() < leader:GetNPC():EntIndex() then
			leader = other
		end
	end
	return leader
end

-- @param position Vector the destination the walk state has picked
-- @return Vector, number|nil, string|nil the destination, the delay before the next pick (nil = the usual one)
--	and the movement type to use (nil = the actor's own)
function GangPack.Destination(actor, position)
	if not actor.data.gang then return position end

	local leader = Leader(actor)
	if leader == actor then
		actor.pack_leader = nil
		return position
	end

	if actor.pack_leader ~= leader then
		local angle = math.random() * math.pi * 2
		local spread = math.random(SPREAD_MIN, SPREAD_MAX)
		actor.pack_leader = leader
		actor.pack_offset = Vector(math.cos(angle) * spread, math.sin(angle) * spread, 0)
	end
	return leader:GetPos() + actor.pack_offset, FOLLOW_DELAY, leader:GetStateData().schedule
end
