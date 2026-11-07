--[[
	Uniform 3D grid of cubic cells. A position maps to its cell in O(1).
	Replaces the slib "Chunks" component (which searched every chunk linearly).

		local grid = bgNPC.SpatialGrid(1000)
		local cell = grid:GetCell(pos)  -- { index, start_pos, end_pos, center_pos }
		grid:Key(pos)                   -- cell index without creating the cell
--]]

local bgNPC = bgNPC
local Vector = Vector
local math_floor = math.floor
--

-- 2^17 cells per axis in each direction keeps the packed key below 2^53 (exact in doubles).
local OFFSET = 131072
local SPAN = 262144

local Grid = bgNPC.Class('SpatialGrid')
bgNPC.SpatialGrid = Grid

function Grid:Init(cell_size)
	self.size = cell_size
	self.cells = {}
	self.count = 0
end

function Grid:Key(pos)
	local size = self.size
	local x = math_floor(pos.x / size) + OFFSET
	local y = math_floor(pos.y / size) + OFFSET
	local z = math_floor(pos.z / size) + OFFSET
	return (x * SPAN + y) * SPAN + z
end

function Grid:GetCell(pos)
	local key = self:Key(pos)
	local cell = self.cells[key]
	if cell then return cell end

	local size = self.size
	local start_pos = Vector(math_floor(pos.x / size) * size, math_floor(pos.y / size) * size, math_floor(pos.z / size) * size)
	local end_pos = start_pos + Vector(size, size, size)
	cell = {
		index = key,
		start_pos = start_pos,
		end_pos = end_pos,
		center_pos = (start_pos + end_pos) * .5,
	}

	self.cells[key] = cell
	self.count = self.count + 1
	return cell
end

-- Cells created so far (keyed by index).
function Grid:GetCells()
	return self.cells
end

function Grid:CellsCount()
	return self.count
end

-- Lets the global IsValid() accept a grid.
function Grid:IsValid()
	return true
end
