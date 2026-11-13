BGN_SEAT = {}
BGN_SEAT.Map = {}

function BGN_SEAT:Instance(pos, ang)
	local obj = {}
	obj.isSeat = true
	obj.start_pos = pos
	obj.position = pos or Vector(0, 0, 0)
	obj.offset = Vector(0, 0, 0)
	obj.angle = ang or Angle(0, 0, 0)
	obj.sitting = NULL

	function obj:GetPos()
		return self.position + self.offset
	end

	function obj:GetAngles()
		return self.angle
	end

	function obj:SetStartSittingPos(start_pos)
		self.start_pos = start_pos
	end

	function obj:GetStartSittingPos()
		return self.start_pos
	end

	function obj:SetOffset(offset)
		self.offset = offset
	end

	function obj:SetSitting(ent)
		self.sitting = ent
	end

	function obj:GetSitting()
		return self.sitting
	end

	return obj
end

function BGN_SEAT:Initialize()
	self:ClearSeats()
	local file_path = 'background_npcs/seats/' .. game.GetMap() .. '.dat'

	if file.Exists(file_path, 'DATA') then
		local read_data = util.JSONToTable(util.Decompress(file.Read(file_path, 'DATA')))

		for i = 1, #read_data do
			local t = read_data[i]
			local seat = self:Instance(t.position, t.angle)
			seat:SetOffset(t.offset)
			seat:SetStartSittingPos(t.start_pos)
			self:AddSeatToMap(seat)
		end
	end
end

function BGN_SEAT:AddSeatToMap(seat)
	if not seat.isSeat then return end
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