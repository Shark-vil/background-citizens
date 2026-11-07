local Assert = bgNPC.Assert
--

BGN_SEAT = {}
BGN_SEAT.Map = {}

local SEAT = {}
SEAT.__index = SEAT
BGN_SEAT.SeatClass = SEAT

function SEAT:GetPos()
	return self.position + self.offset
end

function SEAT:GetAngles()
	return self.angle
end

function SEAT:SetStartSittingPos(start_pos)
	Assert.Arg(1, start_pos, 'vector|nil', 'SEAT:SetStartSittingPos')
	self.start_pos = start_pos or self.position
end

function SEAT:GetStartSittingPos()
	return self.start_pos
end

function SEAT:SetOffset(offset)
	Assert.Arg(1, offset, 'vector|nil', 'SEAT:SetOffset')
	self.offset = offset or Vector(0, 0, 0)
end

function SEAT:SetSitting(ent)
	Assert.Arg(1, ent, 'entity|nil', 'SEAT:SetSitting')
	self.sitting = ent or NULL
end

function SEAT:GetSitting()
	return self.sitting
end

function BGN_SEAT:Instance(pos, ang)
	Assert.Arg(1, pos, 'vector|nil', 'BGN_SEAT:Instance')
	Assert.Arg(2, ang, 'angle|nil', 'BGN_SEAT:Instance')

	local obj = setmetatable({}, SEAT)
	obj.isSeat = true
	obj.position = pos or Vector(0, 0, 0)
	obj.start_pos = obj.position
	obj.offset = Vector(0, 0, 0)
	obj.angle = ang or Angle(0, 0, 0)
	obj.sitting = NULL

	return obj
end

function BGN_SEAT:Initialize()
	self:ClearSeats()

	local file_path = 'background_npcs/seats/' .. game.GetMap() .. '.dat'
	if not file.Exists(file_path, 'DATA') then return end

	local raw_data = util.Decompress(file.Read(file_path, 'DATA') or '')
	local read_data = raw_data and util.JSONToTable(raw_data)
	if not istable(read_data) then
		bgNPC.Util.Log('Failed to read the seats file: ' .. file_path, 'BGN_SEAT:Initialize')
		return
	end

	for i = 1, #read_data do
		local seat_data = read_data[i]
		if istable(seat_data) and isvector(seat_data.position) then
			local seat = self:Instance(seat_data.position, isangle(seat_data.angle) and seat_data.angle or nil)
			seat:SetOffset(isvector(seat_data.offset) and seat_data.offset or nil)
			seat:SetStartSittingPos(isvector(seat_data.start_pos) and seat_data.start_pos or nil)
			self:AddSeatToMap(seat)
		end
	end
end

function BGN_SEAT:AddSeatToMap(seat)
	if not istable(seat) or not seat.isSeat then return end
	table.insert(self.Map, seat)
end

function BGN_SEAT:ClearSeats()
	self.Map = {}
end

function BGN_SEAT:GetAllSeats()
	return self.Map
end

hook.Add('PostCleanupMap', 'BGN_SeatPointsReload', function()
	BGN_SEAT:Initialize()
end)
