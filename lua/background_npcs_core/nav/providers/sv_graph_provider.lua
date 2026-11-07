--[[
	GraphProvider: points and paths over a bgNPC.NodeGraph. Base of the nodegraph and custom providers.
--]]

local Nav = bgNPC.Nav

local GraphProvider = bgNPC.Class('BGN_GraphProvider', Nav.Provider)
Nav.GraphProvider = GraphProvider

local START_SEARCH_RADIUS = 600
local START_CANDIDATES = 6
local EYE = Vector(0, 0, 32)

local world_trace = { mask = MASK_NPCWORLDSTATIC }

local function IsWorldBetween(a, b)
	world_trace.start = a + EYE
	world_trace.endpos = b + EYE
	return util.TraceLine(world_trace).Hit
end
GraphProvider.IsWorldBetween = IsWorldBetween

function GraphProvider:Init(graph)
	self.graph = graph or bgNPC.NodeGraph()
end

function GraphProvider:GetGraph()
	return self.graph
end

function GraphProvider:Count()
	return self.graph:Count()
end

function GraphProvider:GetPointsInRadius(center, radius, link_type)
	local graph = self.graph
	local points = {}
	graph:ForEachInRadius(center, radius, function(id, pos)
		if link_type == nil or graph:HasLinks(id, link_type) then points[#points + 1] = pos end
	end)
	return points
end

function GraphProvider:GetRandomPoint(center, radius, link_type)
	local graph = self.graph
	local id = center and graph:GetRandom(center, radius, link_type) or graph:GetRandom(nil, nil, link_type)
	return id and graph:GetPos(id)
end

-- The nearest few nodes that can be reached in a straight line from pos.
local function FindEntryNode(graph, pos, link_type)
	local candidates = {}
	graph:ForEachInRadius(pos, START_SEARCH_RADIUS, function(id, _, dist_sqr)
		if link_type == nil or graph:HasLinks(id, link_type) then
			candidates[#candidates + 1] = { id = id, dist = dist_sqr }
		end
	end)
	table.sort(candidates, function(a, b) return a.dist < b.dist end)

	for i = 1, math.min(#candidates, START_CANDIDATES) do
		local id = candidates[i].id
		if not IsWorldBetween(pos, graph:GetPos(id)) then return id end
	end

	return candidates[1] and candidates[1].id
end

function GraphProvider:FindPath(start_pos, goal_pos, link_type)
	local graph = self.graph
	if graph:Count() == 0 then return nil end

	local start_id = FindEntryNode(graph, start_pos, link_type)
	local goal_id = FindEntryNode(graph, goal_pos, link_type)
	if not start_id or not goal_id then return nil end

	local ids = graph:FindPath(start_id, goal_id, link_type)
	if not ids then return nil end

	local path = {}
	for i = 1, #ids do path[i] = graph:GetPos(ids[i]) end
	path[#path + 1] = goal_pos

	-- Skip leading nodes the actor can already walk past in a straight line.
	while #path > 1 and not IsWorldBetween(start_pos, path[2]) and start_pos:DistToSqr(path[2]) < 250000 do
		table.remove(path, 1)
	end

	return path
end

function GraphProvider:GetInfo()
	return { provider = self.name, points = self.graph:Count(), links = self.graph:LinksCount() }
end
