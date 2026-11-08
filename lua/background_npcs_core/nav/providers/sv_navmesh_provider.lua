--[[
	NavMeshProvider: the map's NavMesh. Points are random spots on nav areas, paths are A* over areas.
	NextBot bodies walk to far goals by themselves (PathFollower), they get the goal only.
--]]

local Nav = bgNPC.Nav

local NavMeshProvider = bgNPC.Class('BGN_NavMeshProvider', Nav.Provider)
Nav.NavMeshProvider = NavMeshProvider

local MAX_POINTS = 64
local STEP_HEIGHT = 64
local MIN_AREA_SIZE = 16

local function IsWalkable(area)
	return IsValid(area) and not area:IsUnderwater() and area:GetSizeX() >= MIN_AREA_SIZE and area:GetSizeY() >= MIN_AREA_SIZE
end

function NavMeshProvider.IsAvailable()
	return navmesh.IsLoaded() and navmesh.GetNavAreaCount() > 0
end

function NavMeshProvider.HasSavedRoute()
	return false
end

function NavMeshProvider:Load()
	if not NavMeshProvider.IsAvailable() then return false, 'no navmesh' end
	self.count = navmesh.GetNavAreaCount()
	return true
end

function NavMeshProvider:Count()
	return self.count or 0
end

function NavMeshProvider:GetPointsInRadius(center, radius, _, limit)
	local areas = navmesh.Find(center, radius, STEP_HEIGHT * 4, STEP_HEIGHT * 4)
	local points = {}
	local radius_sqr = radius * radius

	for i = 1, #areas do
		local area = areas[i]
		if IsWalkable(area) then
			local point = area:GetCenter()
			if point:DistToSqr(center) <= radius_sqr then points[#points + 1] = point end
		end
	end

	-- Keep the result small but unbiased
	while #points > (limit or MAX_POINTS) do
		local i = math.random(#points)
		points[i] = points[#points]
		points[#points] = nil
	end

	return points
end

-- A random sample, the navmesh can have tens of thousands of areas.
function NavMeshProvider:GetAllPoints()
	local points = {}
	for _ = 1, MAX_POINTS do
		local area = navmesh.GetNavAreaByID(math.random(self:Count()))
		if IsWalkable(area) then points[#points + 1] = area:GetCenter() end
	end
	return points
end

function NavMeshProvider:GetRandomPoint(center, radius)
	if not center then
		local area = navmesh.GetNavAreaByID(math.random(self:Count()))
		return IsWalkable(area) and area:GetRandomPoint() or nil
	end

	local areas = navmesh.Find(center, radius, STEP_HEIGHT * 4, STEP_HEIGHT * 4)
	for _ = 1, 8 do
		local area = areas[math.random(#areas)]
		if IsWalkable(area) then return area:GetRandomPoint() end
	end
end

function NavMeshProvider:FindPath(start_pos, goal_pos)
	local start_area = navmesh.GetNearestNavArea(start_pos, false, 400, false, true)
	local goal_area = navmesh.GetNearestNavArea(goal_pos, false, 400, false, true)
	if not IsValid(start_area) or not IsValid(goal_area) then return nil end

	local goal_center = goal_area:GetCenter()
	local areas = bgNPC.AStar.Search({
		start = start_area,
		max_iterations = 4000,
		is_goal = function(area) return area == goal_area end,
		heuristic = function(area) return area:GetCenter():Distance(goal_center) end,
		neighbours = function(area, push)
			local center = area:GetCenter()
			for _, next_area in ipairs(area:GetAdjacentAreas()) do
				if not next_area:IsUnderwater() then
					push(next_area, center:Distance(next_area:GetCenter()))
				end
			end
		end,
	})
	if not areas then return nil end

	local path = {}
	for i = 2, #areas - 1 do path[#path + 1] = areas[i]:GetCenter() end
	path[#path + 1] = goal_pos
	return path
end

Nav.RegisterProvider('navmesh', NavMeshProvider)
