include('shared.lua')
include('entities/npc_decentvehicle/playermeta.lua')

function ENT:Think()
	self:SetDriverPosition()
	self:SetSequence(self:GetNWInt("Sequence"))
end

function ENT:Draw()
	local seat = self:GetNWEntity("Seat")
	if IsValid(seat) then
		self:SetPos(seat:LocalToWorld(self:GetNWVector "Pos"))
		self:SetAngles(seat:LocalToWorldAngles(self:GetNWAngle "Ang"))
		self:SetupBones()
	end
	self:DrawModel()
end
