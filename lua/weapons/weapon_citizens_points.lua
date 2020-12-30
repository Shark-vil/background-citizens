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

function SWEP:Initialize()
	if SERVER then return end

	hook.Add('PostDrawOpaqueRenderables', self, function()	
		if #self.Points ~= 0 then
			local cam_angle = LocalPlayer():EyeAngles()
			cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
			cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

			if self.Trace ~= nil and self.Lock then
				local pos = self.Trace.HitPos

				render.DrawSphere(pos, 10, 20, 20, Color(255, 225, 0, 200))
				cam.Start3D2D(pos + Vector(0, 0, 20), cam_angle, 0.9)
					draw.SimpleTextOutlined('Слишком далеко от других точек', 
						"TargetID", 0, 0, Color(255, 255, 255), 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, Color(0, 0, 0))
				cam.End3D2D()
			end

			local ply = LocalPlayer()
			render.SetColorMaterial()

			for index, pos in pairs(self.Points) do
				local color

				if index % 2 == 0 then
					color = Color(58, 23, 255, 100)
				else
					color = Color(255, 23, 23, 100)
				end
				
				if bgCitizens:PlayerIsViewVector(ply, pos) and ply:GetPos():Distance(pos) < 1500 then

					for _, otherPos in pairs(self.Points) do
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

						-- draw.SimpleTextOutlined('Z: ' .. tostring(pos.z), 
						-- 	"TargetID", 0, 30, Color(255, 255, 255), 
						-- 	TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, Color(0, 0, 0))
					cam.End3D2D()
				end
            end
        end
	end)
end

function SWEP:Think()
	local owner = self.Owner
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
end

function SWEP:IsReloadDelay()
	self.ReloadDelay = self.ReloadDelay or 0
	if self.ReloadDelay > CurTime() then 
		self.ReloadDelay = CurTime() + 0.3
		return true
	end
	self.ReloadDelay = CurTime() + 0.5
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

function SWEP:CallOnClient(hookType)
	if game.SinglePlayer() then self:CallOnClient(hookType) end
end

function SWEP:PrimaryAttack()
	if SERVER and game.SinglePlayer() then self:CallOnClient('PrimaryAttack') end
	if not IsFirstTimePredicted() then return end

	local hit_vector = self.Trace.HitPos
	if hit_vector ~= nil and not self.Lock then
		self:AddPointPosition(hit_vector + Vector(0, 0, 15))
		if CLIENT then
			surface.PlaySound('common/wpn_select.wav')
		end
	end
end

function SWEP:Reload()
	if SERVER and game.SinglePlayer() then self:CallOnClient('Reload') end
	if self:IsReloadDelay() then return end

	self:ClearPoints()
end

function SWEP:SecondaryAttack()
	if SERVER and game.SinglePlayer() then self:CallOnClient('SecondaryAttack') end
	if not IsFirstTimePredicted() then return end

	self:RemoveLastPoint()
end

function SWEP:OnDrop()
	self:Remove()
end