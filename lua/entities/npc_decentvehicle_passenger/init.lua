local dvd = DecentVehicleDestination
if not dvd then return end
if not file.Exists('entities/npc_decentvehicle/playermeta.lua', 'LUA') then return end

AddCSLuaFile('cl_init.lua')
AddCSLuaFile('shared.lua')
AddCSLuaFile('entities/npc_decentvehicle/playermeta.lua')
include('shared.lua')
include('entities/npc_decentvehicle/playermeta.lua')

function ENT:AttachModel()
	local seat = self.Seat
	self:SetModel(istable(self.Model) and self.Model[math.random(#self.Model)] or self.Model or dvd.DefaultDriverModel[math.random(#dvd.DefaultDriverModel)])
	self:SetNWEntity("Seat", seat)
	self:SetNWEntity("Vehicle", self.v)
	self:SetNWInt("Sequence", self:LookupSequence('Sit'))
	self:SetParent(seat)
	seat:SetSequence(0) -- Resets the sequence first to correct the seat position

	-- Entity:Sequence() will not work properly if it is
	timer.Simple(.1, function()
		if not IsValid(seat) then return end -- called directly after calling Entity:SetModel().
		if not IsValid(self) then return end
		if not IsValid(self.v) then return end
		local a = seat:GetAttachment(assert(seat:LookupAttachment"vehicle_driver_eyes", dvd.Texts.Errors.AttachmentNotFound))
		local d = dvd.SeatPos[self:GetVehicleIdentifier()] or dvd.SeatPos[self:GetVehiclePrefix()] or Vector(-8, 0, -32)
		local seatang = seat:WorldToLocalAngles(a.Ang)
		local seatpos = seat:WorldToLocal(a.Pos + a.Ang:Forward() * d.x + a.Ang:Right() * d.y + a.Ang:Up() * d.z)
		self:SetNWVector("Pos", seatpos)
		self:SetNWAngle("Ang", Angle(0, seatang.y, 0))
		self:SetSequence(self:LookupSequence('Sit'))

		for i = 1, self:GetFlexNum() do
			self:SetFlexWeight(i, self:GetFlexBounds(i))
		end
	end)
end

function ENT:GetVehiclePrefix()
	if self.v.IsScar then
		return "SCAR_"
	elseif self.v.IsSimfphyscar then
		return "Simfphys_"
	else
		return "Source_"
	end
end

function ENT:GetVehicleIdentifier()
	local id = ""

	if self.v.IsScar then
		id = self.v:GetClass()
	elseif self.v.IsSimfphyscar then
		id = self.v:GetModel()
	else
		id = self.v:GetModel()
	end

	return self:GetVehiclePrefix() .. id
end

function ENT:Initialize()
	if not IsValid(self.Seat) or not IsValid(self.v) then
		SafeRemoveEntity(self)
		return
	end

	if not IsValid(self.v) then
		SafeRemoveEntity(self)
		return
	end

	self.Seat.BGN_DecentVehiclePassenger = self
	self:AttachModel()
end

function ENT:Think()
	local actor = self.actor
	local vehicle = self.v

	if not IsValid(vehicle) or not actor or not actor:IsAlive() or not actor:InVehicle() then
		self:Remove()
	end
end