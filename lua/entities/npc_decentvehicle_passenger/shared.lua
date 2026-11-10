ENT.Base = 'base_entity'
ENT.Type = 'anim'
ENT.PrintName = 'DV Passenger'
ENT.DoNotDuplicate = true -- visual helper; its actor is saved separately
ENT.Seat = NULL
ENT.v = NULL
ENT.SeatIndex = -1
ENT.original_VehicleGetPassengerFunction = nil
ENT.original_VehicleGetDriverFunction = nil

-- playermeta.lua uses this for both GetAimVector and eye traces.
function ENT:GetVehicleForward()
	local driver = self.vehicle_provider and self.vehicle_provider:GetVehicleAI()
	if IsValid(driver) then return driver:GetVehicleForward() end
	return self:GetForward()
end

-- list.Set('NPC', 'npc_decentvehicle_passenger', {
-- 	Name = ENT.PrintName,
-- 	Class = 'npc_decentvehicle_passenger',
-- 	Category = 'GreatZenkakuMan\'s NPCs',
-- })

function ENT:SetDriverPosition()
	local seat = self:GetNWEntity('Seat')
	if not IsValid(seat) then return end
	local pos = seat:LocalToWorld(self:GetNWVector'Pos')
	self:SetPos(pos)
	self:SetNetworkOrigin(pos)
	self:SetAngles(seat:LocalToWorldAngles(self:GetNWAngle'Ang'))
end
