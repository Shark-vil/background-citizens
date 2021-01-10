TOOL.Category = 'Background NPCs'
TOOL.Name = '#tool.bgn_point_editor.name'

TOOL.PanelIsInit = false
TOOL.IsBGNPointEditor = true
TOOL.Trace = nil
TOOL.Lock = false
TOOL.Distance = 10000
TOOL.Points = {}
TOOL.RangePoints = {}
TOOL.Delays = {}
TOOL.SelectedPointId = -1
TOOL.Types = {
	[1] = 'creator',
	[2] = 'remover',
	[3] = 'last_remover'
}
TOOL.CurrentTypeId = 1
TOOL.PointToPointLimit = 500
TOOL.IsActive = false
TOOL.vec_30 = Vector(0, 0, 30)

function TOOL:LeftClick()
	if SERVER then
		self:GetOwner():ConCommand('cl_bgn_tool_left_click')
		return
	end
end

function TOOL:RightClick()
	if SERVER then
		self:GetOwner():ConCommand('cl_bgn_tool_right_click')
		return
	end
end

function TOOL:Reload()
	if SERVER then
		self:GetOwner():ConCommand('cl_bgn_tool_reload')
		return
	end
end

if CLIENT then
	concommand.Add('cl_bgn_tool_left_click', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		local hit_vector = tool.Trace.HitPos
		if hit_vector ~= nil then
			local type = tool:GetCurrentType()
			if type == 'creator' then
				if tool.SelectedPointId == -1 then
					local place_vector = hit_vector + Vector(0, 0, 15)
					tool:AddPointPosition(place_vector)
				else
					LocalPlayer():ChatPrint('Don\'t place the points too close to each other!')
				end
			elseif type == 'remover' and tool.SelectedPointId ~= -1 then
				table.remove(tool.Points, tool.SelectedPointId)
				tool.SelectedPointId = -1
				surface.PlaySound('common/wpn_denyselect.wav')
			elseif type == 'last_remover' then
				tool:RemoveLastPoint()
			end
		end
	end)

	concommand.Add('cl_bgn_tool_right_click', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		tool:SwitchType()
		surface.PlaySound('buttons/blip1.wav')
	end)

	concommand.Add('cl_bgn_tool_reload', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		tool:ClearPoints()
	end)

	function TOOL:SwitchType()
		local id = self.CurrentTypeId
		if id + 1 > #self.Types then
			self.CurrentTypeId = 1
		else
			self.CurrentTypeId = id + 1
		end
	end

	function TOOL:GetCurrentType()
		return self.Types[self.CurrentTypeId]
	end

	function TOOL:IsLookingVector(vec)
		local diff = vec - self:GetOwner():GetShootPos()
		return self:GetOwner():GetAimVector():Dot(diff) / diff:Length() >= 0.998
	end

	function TOOL:Think()
		if SERVER then return end

		local owner = self:GetOwner()

		if IsValid(owner) and owner:Alive() then
			self.PointToPointLimit = GetConVar('bgn_ptp_distance_limit'):GetFloat()

			local isSelectedPoint = false
			local NewRangePoints = {}

			for index, pos in ipairs(self.Points) do
				if bgNPC:PlayerIsViewVector(owner, pos)
					and owner:GetPos():DistToSqr(pos) < 2250000 -- 1500 ^ 2
				then
					table.insert(NewRangePoints, {
						index = index,
						pos = pos
					})

					if not isSelectedPoint and self:IsLookingVector(pos) then
						self.SelectedPointId = index
						isSelectedPoint = true
					end
				end
			end

			if not isSelectedPoint then
				self.SelectedPointId = -1
			end

			self.RangePoints = NewRangePoints

			self.Trace = util.TraceLine( {
				start = owner:GetShootPos(),
				endpos = owner:GetShootPos() + owner:GetAimVector() * self.Distance,
				filter = function(ent)
					if ent ~= LocalPlayer() then 
						return true
					end
				end
			} )

			if #self.Points ~= 0 then
				if self.Trace ~= nil then
					local awayAllow = true
					local pos = self.Trace.HitPos
					local z_limit = GetConVar('bgn_point_z_limit'):GetInt()

					for _, pointPos in ipairs(self.Points) do
						if pos:DistToSqr(pointPos) <= self.PointToPointLimit ^ 2 then
							local mainZ = pos.z
							local otherZ = pointPos.z

							if mainZ >= otherZ - z_limit and mainZ <= otherZ + z_limit then
								local tr = util.TraceLine({
									start = pos + self.vec_30,
									endpos = pointPos,
									filter = function(ent)
										if ent:IsWorld() then
											return true
										end
									end
								})

								if not tr.Hit then
									awayAllow = false
									break
								end
							end
						end
					end

					if awayAllow then
						self.Lock = true
						return
					end
				end
			end
		end

		self.Lock = false
		self:UpdateControlPanel()
	end

	function TOOL:AddPointPosition(value)
		table.insert(self.Points, value)
		surface.PlaySound('common/wpn_select.wav')
	end

	function TOOL:RemoveLastPoint()
		local max = #self.Points
		if max - 1 >= 0 then
			table.remove(self.Points, max)
			surface.PlaySound('common/wpn_denyselect.wav')
		end
	end

	function TOOL:ClearPoints()
		table.Empty(self.Points)
		surface.PlaySound('common/wpn_denyselect.wav')
	end

	function TOOL:DrawHUD()
		surface.SetFont('Trebuchet24')
		surface.SetTextColor(255, 255, 255)
		surface.SetTextPos(30, ScrH() / 2)
		local type = self:GetCurrentType()
		if type == 'creator' then
			surface.DrawText('Creating points')
		elseif type == 'remover' then
			surface.DrawText('Deleting a selected point')
		elseif type == 'last_remover' then
			surface.DrawText('Delete last point - ' .. tostring(#self.Points))
		end
	end

	function TOOL:UpdateControlPanel()
		local Panel = controlpanel.Get( 'bgn_point_editor' )
		if not Panel then MsgN( 'Couldn\'t find bgn_point_editor panel!' ) return end
		if self.PanelIsInit then return end

		self.PanelIsInit = true

		Panel:ClearControls()

		Panel:AddControl('Button', {
			['Label'] = 'Load points',
			['Command'] = 'cl_citizens_load_route_from_client',
		})

		Panel:AddControl('Button', {
			['Label'] = 'Save points',
			['Command'] = 'cl_citizens_save_route',
		})

		Panel:AddControl('Slider', {
			['Label'] = 'Distance between points limit (Works only on maps with a navigation mesh)',
			['Command'] = 'bgn_ptp_distance_limit',
			['Type'] = 'Float',
			['Min'] = '0',
			['Max'] = '3000'
		}); Panel:AddControl('Label', {
			Text = 'Description: You can change the point-to-point limit for the instrument if you have a navigation mesh on your map.'
		})

		Panel:AddControl('Slider', {
			['Label'] = 'Height limit between points.',
			['Command'] = 'bgn_point_z_limit',
			['Type'] = 'Float',
			['Min'] = '0',
			['Max'] = '500'
		}); Panel:AddControl('Label', {
			Text = 'Description: Height limit between points. Used to correctly define child points.'
		})
	end

	language.Add( 'tool.bgn_point_editor.name', 'Points Editor' )

	local clr = Color(255, 225, 0, 200)
	local clr_green = Color(72, 232, 9, 200)
	local clr_58 = Color(58, 23, 255, 100)
	local clr_255 = Color(255, 23, 23, 100)
	local vec_20 = Vector(0, 0, 20)
	local vec_30 = Vector(0, 0, 30)
	local color_white = Color(255, 255, 255)
	local color_black = Color(0, 0, 0)

	hook.Add('BGN_LoadingClientRoutes', 'BGN_TOOL_LoadPointRoutes', function(points)
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end
		tool.Points = {}
		for index, v in pairs(points) do
			tool.Points[index] = v.pos
		end
	end)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRenderPoints', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		render.SetColorMaterial()

		local cam_angle = LocalPlayer():EyeAngles()
		cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
		cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

		if tool.Trace ~= nil and tool:GetCurrentType() == 'creator' then
			local pos = tool.Trace.HitPos

			if tool.Lock then
				render.DrawSphere(pos, 10, 20, 20, clr)
				cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
					draw.SimpleTextOutlined('Too far from other points',
						'TargetID', 0, 0, color_white,
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				cam.End3D2D()
			else
				if tool.SelectedPointId == -1 then
					render.DrawSphere(pos, 10, 20, 20, clr_green)
					cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
						draw.SimpleTextOutlined('Good place',
							'TargetID', 0, 0, color_white,
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
					cam.End3D2D()
				end
			end
		end

		if #tool.RangePoints ~= 0 then
			local z_limit = GetConVar('bgn_point_z_limit'):GetInt()
			for _, value in ipairs(tool.RangePoints) do
				local index = value.index
				local pos = value.pos
				local color

				if index % 2 == 0 then
					color = clr_58
				else
					color = clr_255
				end

				for _, otherValue in ipairs(tool.RangePoints) do
					local otherPos = otherValue.pos
					if otherPos:DistToSqr(pos) <= tool.PointToPointLimit ^ 2 then
						local mainZ = pos.z
						local otherZ = otherPos.z

						if mainZ >= otherZ - z_limit and mainZ <= otherZ + z_limit then
							local tr = util.TraceLine({
								start = pos + vec_30,
								endpos = otherPos,
								filter = function(ent)
									return ent:IsWorld()
								end
							})

							if not tr.Hit then
								render.DrawLine(pos, otherPos, color)
							end
						end
					end
				end

				render.DrawSphere(pos, 10, 30, 30, color)

				cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
					draw.SimpleTextOutlined(tostring(index),
						'TargetID', 0, 0, color_white,
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)

					if value.index == tool.SelectedPointId then
						draw.SimpleTextOutlined('Selected',
							'TargetID', 0, 25, color_white,
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
					end
				cam.End3D2D()
			end
		end
	end)
end