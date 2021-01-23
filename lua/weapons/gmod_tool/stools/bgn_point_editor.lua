TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_point_editor.name"

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
		local diff = vec - self.Owner:GetShootPos()
		return self.Owner:GetAimVector():Dot(diff) / diff:Length() >= 0.998
	end
	
	function TOOL:Think()
		if SERVER then return end
	
		local owner = self.Owner
	
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
					local mainZ = pos.z

					for _, pointPos in ipairs(self.Points) do
						if pos:DistToSqr(pointPos) <= self.PointToPointLimit ^ 2 then
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
		surface.SetFont("Trebuchet24")
		surface.SetTextColor(255, 255, 255)
		surface.SetTextPos(30, ScrH() / 2) 
		local type = self:GetCurrentType()
		if type == 'creator' then
			surface.DrawText('#tool.bgn_point_editor.vis.creator')
		elseif type == 'remover' then
			surface.DrawText('#tool.bgn_point_editor.vis.remover')
		elseif type == 'last_remover' then
			surface.DrawText(language.GetPhrase('tool.bgn_point_editor.vis.last_remover')
				.. ' - ' .. tostring(#self.Points))
		end
	end
	
	function TOOL:UpdateControlPanel()
		local Panel = controlpanel.Get( "bgn_point_editor" )
		if not Panel then bgNPC:Log("Couldn't find bgn_point_editor panel!", 'Tool') return end
		if self.PanelIsInit then return end
	
		self.PanelIsInit = true
	
		Panel:ClearControls()
	
		Panel:AddControl("Button", {
			["Label"] = "#tool.bgn_point_editor.pnl.load_points",
			["Command"] = "cl_citizens_load_route_from_client",
		})
	
		Panel:AddControl("Button", {
			["Label"] = "#tool.bgn_point_editor.pnl.save_points",
			["Command"] = "cl_citizens_save_route",
		})
	
		Panel:AddControl("Slider", {
			["Label"] = "#tool.bgn_point_editor.pnl.ptp_dist",
			["Command"] = "bgn_ptp_distance_limit",
			["Type"] = "Float",
			["Min"] = "0",
			["Max"] = "3000"
		}); Panel:AddControl('Label', {
			Text = '#tool.bgn_point_editor.pnl.ptp_dist.desc'
		})
	
		Panel:AddControl("Slider", {
			["Label"] = "#tool.bgn_point_editor.pnl.z_limit",
			["Command"] = "bgn_point_z_limit",
			["Type"] = "Float",
			["Min"] = "0",
			["Max"] = "500"
		}); Panel:AddControl('Label', {
			Text = '#tool.bgn_point_editor.pnl.z_limit.desc'
		})
	end
	
	local en_lang = {
		['tool.bgn_point_editor.name'] = 'Points Editor',
		['tool.bgn_point_editor.desc'] = 'Tool for editing the points of movement of background NPCs.',
		['tool.bgn_point_editor.0'] = 'Left click - Interaction. Right click - Change tool type. Reload - Clear all points.',
		['tool.bgn_point_editor.pnl.load_points'] = 'Load points',
		['tool.bgn_point_editor.pnl.save_points'] = 'Save points',
		['tool.bgn_point_editor.pnl.ptp_dist'] = 'Distance between points limit (Works only on maps with a navigation mesh)',
		['tool.bgn_point_editor.pnl.ptp_dist.desc'] = 'Description: You can change the point-to-point limit for the instrument if you have a navigation mesh on your map.',
		['tool.bgn_point_editor.pnl.z_limit'] = 'Height limit between points',
		['tool.bgn_point_editor.pnl.z_limit.desc'] = 'Description: Height limit between points. Used to correctly define child points.',
		['tool.bgn_point_editor.vis.good_place'] = 'Good place',
		['tool.bgn_point_editor.vis.lock_pos'] = 'Too far from other points',
		['tool.bgn_point_editor.vis.creator'] = 'Creating points',
		['tool.bgn_point_editor.vis.remover'] = 'Deleting a selected point',
		['tool.bgn_point_editor.vis.last_remover'] = 'Delete last point',
		['tool.bgn_point_editor.vis.selected'] = 'Selected',
	}

	local ru_lang = {
		['tool.bgn_point_editor.name'] = 'Редактор точек',
		['tool.bgn_point_editor.desc'] = 'Инструмент для редактирования точек перемещения фоновых НПС.',
		['tool.bgn_point_editor.0'] = 'Левый клик - Взаимодействие. Правый клик - Сменить тип инструмента. Перезарядка - Очистить все точки.',
		['tool.bgn_point_editor.pnl.load_points'] = 'Загрузить точки',
		['tool.bgn_point_editor.pnl.save_points'] = 'Сохранить точки',
		['tool.bgn_point_editor.pnl.ptp_dist'] = 'Ограничение расстояния между точками (работает только на картах с навигационной сеткой)',
		['tool.bgn_point_editor.pnl.ptp_dist.desc'] = 'Описание: вы можете изменить ограничение «от точки до точки» для инструмента, если на вашей карте есть навигационная сетка.',
		['tool.bgn_point_editor.pnl.z_limit'] = 'Ограничение высоты между точками',
		['tool.bgn_point_editor.pnl.z_limit.desc'] = 'Описание: Ограничение высоты между точками. Используется для правильного определения дочерних точек.',
		['tool.bgn_point_editor.vis.good_place'] = 'Хорошая позиция',
		['tool.bgn_point_editor.vis.lock_pos'] = 'Слишком далеко от других точек',
		['tool.bgn_point_editor.vis.creator'] = 'Создание точек',
		['tool.bgn_point_editor.vis.remover'] = 'Удаление выбранной точки',
		['tool.bgn_point_editor.vis.last_remover'] = 'Удалить последнюю точку',
		['tool.bgn_point_editor.vis.selected'] = 'Выбрано',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end

	local clr = Color(255, 225, 0, 200)
	local clr_green = Color(72, 232, 9, 200)
	local clr_58 = Color(58, 23, 255, 100)
	local clr_255 = Color(255, 23, 23, 100)
	local vec_20 = Vector(0, 0, 20)
	local vec_30 = Vector(0, 0, 30)
	local color_white = Color(255, 255, 255)
	local color_black = Color(0, 0, 0)

	hook.Add("BGN_LoadingClientRoutes", "BGN_TOOL_LoadPointRoutes", function(points)
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		tool.Points = {}
		for index, v in pairs(points) do
			tool.Points[index] = v.pos
		end
	end)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRenderPoints', function()
		local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end

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
					draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.lock_pos', 
						"TargetID", 0, 0, color_white, 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				cam.End3D2D()
			else
				if tool.SelectedPointId == -1 then
					render.DrawSphere(pos, 10, 20, 20, clr_green)
					cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
						draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.good_place', 
							"TargetID", 0, 0, color_white, 
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
				local mainZ = pos.z
				local color

				if index % 2 == 0 then
					color = clr_58
				else
					color = clr_255
				end
				
				for _, otherValue in ipairs(tool.RangePoints) do
					local otherPos = otherValue.pos
					if otherPos:DistToSqr(pos) <= tool.PointToPointLimit ^ 2 then
						local otherZ = otherPos.z

						if mainZ >= otherZ - z_limit and mainZ <= otherZ + z_limit then
							local tr = util.TraceLine({
								start = pos + vec_30,
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

				cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
					draw.SimpleTextOutlined(tostring(index), 
						"TargetID", 0, 0, color_white, 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)

					if value.index == tool.SelectedPointId then
						draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.selected', 
							"TargetID", 0, 25, color_white, 
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
					end
				cam.End3D2D()
			end
		end
	end)
end