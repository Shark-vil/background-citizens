TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_point_editor.name"

TOOL.PanelIsInit = false
TOOL.IsBGNPointEditor = true
TOOL.Lock = false
TOOL.Distance = 10000
TOOL.RangePoints = {}
TOOL.Delays = {}
TOOL.SelectedPointId = -1
TOOL.Types = {
	[1] = 'creator',
	[2] = 'remover',
	[3] = 'last_remover',
	[4] = 'linker',
	[5] = 'parents_cleaner',
}
TOOL.CurrentTypeId = 1
TOOL.IsActive = false
TOOL.vec_30 = Vector(0, 0, 30)
TOOL.LinkerNode = nil

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

function TOOL:GetTraceInfo()
	local ply = self:GetOwner()
	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
		filter = function(ent)
			if ent ~= ply then
				return true
			end
		end
	})

	return tr
end

if CLIENT then
	hook.Add('BGN_LoadingClientRoutes', 'BGN_TOOL_PointEditorReset', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end
		tool.LinkerNode = nil
	end)

	concommand.Add('cl_bgn_tool_left_click', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		local type = tool:GetCurrentType()
			
		if type == 'creator' then
			if tool.SelectedPointId == -1 then
				tool:AddNode()
			else
				LocalPlayer():ChatPrint('Don\'t place the points too close to each other!')
			end
		elseif type == 'remover' and tool.SelectedPointId ~= -1 then
			local node = BGN_NODE:GetNodeByIndex(tool.SelectedPointId)
			if node then tool:RemoveNode(node) end
		elseif type == 'last_remover' then
			tool:RemoveLastNode()
		elseif type == 'linker' and tool.SelectedPointId ~= -1 then
			local node = BGN_NODE:GetNodeByIndex(tool.SelectedPointId)
			if not tool.LinkerNode then
				tool.LinkerNode = node
				surface.PlaySound('common/wpn_select.wav')
			elseif tool.LinkerNode ~= node then
				if tool.LinkerNode:HasParent(node) then
					tool.LinkerNode:RemoveParentNode(node)
				else
					tool.LinkerNode:AddParentNode(node)
				end

				tool.LinkerNode = nil
				surface.PlaySound('common/wpn_denyselect.wav')
			end
		elseif type == 'parents_cleaner' and tool.SelectedPointId ~= -1 then
			local node = BGN_NODE:GetNodeByIndex(tool.SelectedPointId)
			node:ClearParents()
			surface.PlaySound('common/wpn_denyselect.wav')
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

	concommand.Add('cl_tool_point_editor_reconstruct_parents', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		for _, node in ipairs(BGN_NODE:GetMap()) do
			table.Empty(node.parents)
		end

		for _, node in ipairs(BGN_NODE:GetMap()) do
			tool:ConstructParent(node)
		end
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
	
		if not owner:Alive() then return end

		local dist = GetConVar('bgn_tool_draw_distance'):GetFloat() ^ 2

		local NewSelectedPointId = -1
		local NewRangePoints = {}
		local nodes = BGN_NODE:GetNodeMap()

		for index, node in ipairs(nodes) do
			local pos = node:GetPos()

			if bgNPC:PlayerIsViewVector(owner, pos) and owner:GetPos():DistToSqr(pos) <= dist then
				local tr = util.TraceLine({
					start = owner:GetShootPos(),
					endpos = node.position,
					filter = function(ent)
						if ent:IsWorld() then
							return true
						end
					end
				})

				table.insert(NewRangePoints, {
					index = index,
					node = node,
					behindTheWall = tr.Hit
				})

				if NewSelectedPointId == -1 and self:IsLookingVector(pos) then
					if not tr.Hit then NewSelectedPointId = index end
				end
			end
		end

		self.SelectedPointId = NewSelectedPointId
		self.RangePoints = NewRangePoints

		self:UpdateControlPanel()
	end
	
	function TOOL:AddNode()
		local tr = self:GetTraceInfo()
		if not tr.Hit then return end

		local node = BGN_NODE:Instance(tr.HitPos + Vector(0, 0, 10))
		BGN_NODE:AddNodeToMap(node)

		surface.PlaySound('common/wpn_select.wav')

		self:ConstructParent(node)
	end

	function TOOL:RemoveNode(node)
		node:RemoveFromMap()
		surface.PlaySound('common/wpn_denyselect.wav')
	end
	
	function TOOL:RemoveLastNode()
		local nodes = BGN_NODE:GetNodeMap()
		local count = #nodes

		if count == 0 then return end

		local node = nodes[count]
		if not node then return end

		self:RemoveNode(node)
	end
	
	function TOOL:ClearPoints()
		BGN_NODE:ClearNodeMap()
		surface.PlaySound('common/wpn_denyselect.wav')
	end

	function TOOL:ConstructParent(node)
		for _, anotherNode in ipairs(BGN_NODE:GetNodeMap()) do
			local pos = anotherNode:GetPos()
			
			if not anotherNode:HasParent(node) and node:CheckDistanceLimitToNode(pos) 
				and node:CheckHeightLimitToNode(pos)
			then
				anotherNode:AddParentNode(node)
			end
		end
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
				.. ' - ' .. tostring(BGN_NODE:CountNodesOnMap()))
		elseif type == 'linker' then
			surface.DrawText('#tool.bgn_point_editor.vis.linker')
		elseif type == 'parents_cleaner' then
			surface.DrawText('#tool.bgn_point_editor.vis.parents_cleaner')
		end
	end
	
	function TOOL:UpdateControlPanel()
		if self.PanelIsInit then return end

		local Panel = controlpanel.Get( "bgn_point_editor" )
		if not Panel then bgNPC:Log("Couldn't find bgn_point_editor panel!", 'Tool') return end
	
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

		Panel:AddControl("Button", {
			["Label"] = "#tool.bgn_point_editor.pnl.reconstruct_parents",
			["Command"] = "cl_tool_point_editor_reconstruct_parents",
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

		Panel:AddControl("Slider", {
			["Label"] = "#tool.bgn_point_editor.pnl.bgn_tool_draw_distance",
			["Command"] = "bgn_tool_draw_distance",
			["Type"] = "Float",
			["Min"] = "0",
			["Max"] = "2000"
		}); Panel:AddControl('Label', {
			Text = '#tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'
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
		['tool.bgn_point_editor.vis.linker'] = 'Linker node',
		['tool.bgn_point_editor.vis.parents_cleaner'] = 'Cleaner node links',
		['tool.bgn_point_editor.vis.selected'] = 'Selected',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance'] = 'Distance to draw points',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'] = 'Description: sets the maximum distance to draw points in edit mode.',
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
		['tool.bgn_point_editor.vis.linker'] = 'Соединитель',
		['tool.bgn_point_editor.vis.parents_cleaner'] = 'Очиститель связей',
		['tool.bgn_point_editor.vis.selected'] = 'Выбрано',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance'] = 'Дистанция прорисовки точек',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'] = 'Описание: устанавливает максимальное расстояние отрисовки точек в режиме редактирования.',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end

	local clr = Color(255, 225, 0, 200)
	local clr_green = Color(72, 232, 9, 200)
	local clr_link = Color(0, 238, 255, 200)
	local clr_link_alpha = Color(68, 123, 135, 50)
	local clr_point = Color(255, 23, 23, 200)
	local vec_20 = Vector(0, 0, 20)
	local color_white = Color(255, 255, 255)
	local color_black = Color(0, 0, 0)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRenderPoints', function()
		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end

		local tool = ply:GetTool()
		if tool == nil or not tool.IsBGNPointEditor then return end

		render.SetColorMaterial()

		local cam_angle = ply:EyeAngles()
		cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
		cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

		local tr = tool:GetTraceInfo()
		if tr.Hit and tool:GetCurrentType() == 'creator' then
			local tracePos = tr.HitPos
			local tooFar = true

			if BGN_NODE:CountNodesOnMap() == 0 then
				tooFar = false
			else
				for _, node in ipairs(BGN_NODE:GetNodeMap()) do
					if node:CheckDistanceLimitToNode(tracePos) and node:CheckHeightLimitToNode(tracePos) then
						tooFar = false
						break
					end
				end
			end

			if tooFar then
				render.DrawSphere(tracePos, 10, 20, 20, clr)
				cam.Start3D2D(tracePos + vec_20, cam_angle, 0.9)
					draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.lock_pos', 
						"TargetID", 0, 0, color_white, 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				cam.End3D2D()
			else
				if tool.SelectedPointId == -1 then
					render.DrawSphere(tracePos, 10, 20, 20, clr_green)
					cam.Start3D2D(tracePos + vec_20, cam_angle, 0.9)
						draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.good_place', 
							"TargetID", 0, 0, color_white, 
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
					cam.End3D2D()
				end
			end
		end

		if #tool.RangePoints == 0 then return end

		local IsDrawingParentsNode = {}

		for _, value in ipairs(tool.RangePoints) do
			local index = value.index
			local node = value.node
			table.insert(IsDrawingParentsNode, node)

			local pos = node:GetPos()

			for _, parentNode in ipairs(node.parents) do
				if not table.HasValue(IsDrawingParentsNode, parentNode) then
					if value.behindTheWall then
						render.DrawLine(pos, parentNode:GetPos(), clr_link_alpha)
					else
						render.DrawLine(pos, parentNode:GetPos(), clr_link)
					end
				end
			end

			render.DrawSphere(pos, 10, 30, 30, clr_point)

			cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
				draw.SimpleTextOutlined(tostring(index), 
					"TargetID", 0, 0, color_white, 
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)

				-- local x, y = node:GetChunkID()
				-- draw.SimpleTextOutlined(tostring(x .. y), 
				-- 	"TargetID", 0, -35, color_white, 
				-- 	TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)

				if value.index == tool.SelectedPointId then
					draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.selected', 
						"TargetID", 0, 25, color_white, 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				end
			cam.End3D2D()
		end
	end)
end