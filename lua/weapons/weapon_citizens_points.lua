AddCSLuaFile()

SWEP.PrintName = "Points creator"
SWEP.Author = "Shark_vil"
SWEP.Purpose = "Create points for selected event."
SWEP.Category = 'Background Citizens'

SWEP.AdminOnly = true

SWEP.Slot = 0
SWEP.SlotPos = 4

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_toolgun.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_toolgun.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Trace = nil
SWEP.Lock = false
SWEP.DrawAmmo = false
SWEP.Distance = 1000
SWEP.Points = {}
SWEP.RangePoints = {}

SWEP.Delays = {}

function SWEP:Initialize()
	self.Points = {}
	for index, v in pairs(bgCitizens.points) do
		self.Points[index] = v.pos
	end

	if SERVER then return end

	hook.Add('PostDrawOpaqueRenderables', self, function()	
		if #self.RangePoints ~= 0 then
			local cam_angle = LocalPlayer():EyeAngles()
			cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
			cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

			if self.Trace ~= nil and self.Lock then
				local pos = self.Trace.HitPos

				render.DrawSphere(pos, 10, 20, 20, Color(255, 225, 0, 200))
				cam.Start3D2D(pos + Vector(0, 0, 20), cam_angle, 0.9)
					draw.SimpleTextOutlined('Too far from other points', 
						"TargetID", 0, 0, Color(255, 255, 255), 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, Color(0, 0, 0))
				cam.End3D2D()
			end

			local ply = LocalPlayer()
			render.SetColorMaterial()

			for _, value in pairs(self.RangePoints) do
				local index = value.index
				local pos = value.pos
				local color

				if index % 2 == 0 then
					color = Color(58, 23, 255, 100)
				else
					color = Color(255, 23, 23, 100)
				end
				
				for _, otherValue in pairs(self.RangePoints) do
					local otherPos = otherValue.pos
					if otherPos:Distance(pos) <= 500 then
						local mainZ = pos.z
						local otherZ = otherPos.z

						if mainZ >= otherZ - 100 and mainZ <= otherZ + 100 then
							local tr = util.TraceLine( {
								start = pos + Vector(0, 0, 30),
								endpos = otherPos,
								filter = function(ent)
									if ent:IsWorld() then
										return true
									end
								end
							})

							if not tr.Hit then
								render.DrawLine(pos, otherPos, color)
							end
						end
					end
				end

				render.DrawSphere(pos, 10, 30, 30, color)

				cam.Start3D2D(pos + Vector(0, 0, 20), cam_angle, 0.9)
					draw.SimpleTextOutlined(tostring(index), 
						"TargetID", 0, 0, Color(255, 255, 255), 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, Color(0, 0, 0))
				cam.End3D2D()
            end
        end
	end)
end

function SWEP:Think()
	local owner = self.Owner

	if IsValid(owner) and owner:Alive() then
		local NewRangePoints = {}
		for index, pos in pairs(self.Points) do
			if bgCitizens:PlayerIsViewVector(owner, pos) and owner:GetPos():Distance(pos) < 1500 then
				table.insert(NewRangePoints, {
					index = index,
					pos = pos,
				})
			end
		end
		self.RangePoints = NewRangePoints

		self.Trace = util.TraceLine( {
			start = owner:GetShootPos(),
			endpos = owner:GetShootPos() + owner:GetAimVector() * self.Distance,
			filter = function(ent)
				if IsValid(ent) and ent:IsPlayer() then 
					return false
				end
				return true
			end
		} )

		if #self.Points ~= 0 then
			if self.Trace ~= nil then
				local awayAllow = true
				local pos = self.Trace.HitPos

				for _, pointPos in pairs(self.Points) do
					if pos:Distance(pointPos) <= 500 then
						awayAllow = false
						break
					end
				end

				if awayAllow then
					self.Lock = true
					return
				end
			end
		end

		self.Lock = false
	else
		self.Lock = true
	end
end

function SWEP:IsDelay(name)
	self.Delays[name] = self.Delays[name] or 0
	if self.Delays[name] > CurTime() then 
		self.Delays[name] = CurTime() + 0.1
		return true
	end
	self.Delays[name] = CurTime() + 0.1
	return false
end

function SWEP:AddPointPosition(value)
	table.insert(self.Points, value)
end

function SWEP:RemoveLastPoint()
    local max = #self.Points
    if max - 1 >= 0 then
        table.remove(self.Points, max)
    end
end

function SWEP:ClearPoints()
	table.Empty(self.Points)
	
	if CLIENT then
		surface.PlaySound('common/wpn_denyselect.wav')
	end
end

function SWEP:ClientRPC(hookType)
	if SERVER and game.SinglePlayer() then self:CallOnClient(hookType) end
end

function SWEP:PrimaryAttack()
	if self:IsDelay("PrimaryAttack") then return end
	if CLIENT then return end

	local hit_vector = self.Trace.HitPos
	if hit_vector ~= nil and not self.Lock then
		local place_vector = hit_vector + Vector(0, 0, 15)
		self:AddPointPosition(place_vector)

		net.Start('bgCitizensAddRouteVectorFromClient')
		net.WriteVector(place_vector)
		net.Send(self.Owner)
	end
end

function SWEP:Reload()
	if self:IsDelay("Reload") then return end
	self:ClientRPC('Reload')

	self:ClearPoints()
end

function SWEP:SecondaryAttack()
	if self:IsDelay("SecondaryAttack") then return end
	self:ClientRPC('SecondaryAttack')

	self:RemoveLastPoint()
end

function SWEP:OnDrop()
	self:Remove()
end