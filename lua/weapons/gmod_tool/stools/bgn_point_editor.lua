TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_point_editor.name"
TOOL.PanelIsInit = false
TOOL.Lock = false
TOOL.Distance = 10000
TOOL.RangePoints = {}
TOOL.Delays = {}
TOOL.SelectedPointId = -1
TOOL.Types = {
	[1] = 'creator',
	[2] = 'remover',
	[3] = 'linker',
	[4] = 'parents_cleaner',
}
TOOL.CurrentTypeId = 1
TOOL.IsActive = false
TOOL.vec_30 = Vector(0, 0, 30)
TOOL.LinkerNode = nil
TOOL.CreateSelectedNode = nil
TOOL.LinkFullParents = false
TOOL.LastNodeRemover = false

if SERVER then
	function TOOL:LeftClick()
		snet.ClientRPC(self, 'LeftClick')
	end

	function TOOL:RightClick()
		snet.ClientRPC(self, 'RightClick')
	end

	function TOOL:Reload()
		snet.ClientRPC(self, 'Reload')
	end
else
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

	hook.Add('BGN_LoadingClientRoutes', 'BGN_TOOL_PointEditorReset', function()
		local tool = bgNPC:GetActivePlayerTool('bgn_point_editor')
      if not tool then return end

		tool.LinkerNode = nil
		tool.CreateSelectedNode = nil
	end)

	function TOOL:LeftClick()
		local type = self:GetCurrentType()
			
		if type == 'creator' then
			if self.SelectedPointId == -1 then
				self:AddNode()
			else
				local node = BGN_NODE:GetNodeByIndex(self.SelectedPointId)
				if node then
					if node == self.CreateSelectedNode then
						self.CreateSelectedNode = nil
					elseif not self.CreateSelectedNode then
						self.CreateSelectedNode = node
					else
						self:AddNode()
					end
				end
			end
		elseif type == 'remover' then
			if self.LastNodeRemover then
				self:RemoveLastNode()
			elseif self.SelectedPointId ~= -1 then
				local node = BGN_NODE:GetNodeByIndex(self.SelectedPointId)
				if node then self:RemoveNode(node) end
			end
		elseif type == 'linker' and self.SelectedPointId ~= -1 then
			local node = BGN_NODE:GetNodeByIndex(self.SelectedPointId)
			if not self.LinkerNode then
				self.LinkerNode = node
				surface.PlaySound('common/wpn_select.wav')
			else
				if self.LinkerNode == node then
					self.LinkerNode = nil
					surface.PlaySound('common/wpn_denyselect.wav')
				else
					if self.LinkFullParents then
						if self.LinkerNode:HasParent(node) then
							self.LinkerNode:RemoveParentNode(node)
						elseif self.LinkerNode.position:DistToSqr(node.position) <= 250000 then
							self.LinkerNode:AddParentNode(node)
						end
					else
						if self.LinkerNode:HasLink(node, 'walk') then
							self.LinkerNode:RemoveLink(node, 'walk')
						elseif self.LinkerNode.position:DistToSqr(node.position) <= 250000 then
							self.LinkerNode:AddLink(node, 'walk')
						end
					end

					self.LinkerNode = nil
					surface.PlaySound('common/wpn_denyselect.wav')
				end
			end
		elseif type == 'parents_cleaner' and self.SelectedPointId ~= -1 then
			local node = BGN_NODE:GetNodeByIndex(self.SelectedPointId)
			if self.LinkFullParents then
				node:ClearParents()
			else
				node:ClearLinks('walk')
			end
			surface.PlaySound('common/wpn_denyselect.wav')
		end
	end

	function TOOL:RightClick()
		self.LinkerNode = nil
		self.SelectedPointId = nil

		self:SwitchType()
		surface.PlaySound('buttons/blip1.wav')
	end

	function TOOL:Reload()
		local type = self:GetCurrentType()

		if type == 'remover' or type == 'last_remover' then
			self.LastNodeRemover = not self.LastNodeRemover
		elseif type == 'linker' or type == 'parents_cleaner' then
			self.LinkFullParents = not self.LinkFullParents
		end

		surface.PlaySound('buttons/blip1.wav')
	end

	concommand.Add('cl_tool_point_editor_reconstruct_parents', function()
		if not SLibraryIsLoaded then return end

      local tool = LocalPlayer():slibGetActiveTool('bgn_point_editor')
      if not tool then return end

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

		self.CreateSelectedNode = nil
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

		if not timer.Exists('BGN_PointEditorToolRefreshRangePoints') then
			timer.Create('BGN_PointEditorToolRefreshRangePoints', 0.2, 0, function()
				local wep = LocalPlayer():GetActiveWeapon()
				if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then
					timer.Remove('BGN_PointEditorToolRefreshRangePoints')
					return
				end
		
				local tool = bgNPC:GetActivePlayerTool('bgn_point_editor')
				if not tool then
					timer.Remove('BGN_PointEditorToolRefreshRangePoints')
					return
				end
		
				local dist = GetConVar('bgn_tool_draw_distance'):GetFloat() ^ 2
				local NewSelectedPointId = -1
				local NewRangePoints = {}
				local nodes = BGN_NODE:GetNodeMap()

				for index = 1, #nodes do
					local node = nodes[index]
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

						if NewSelectedPointId == -1 and tool:IsLookingVector(pos) then
							if not tr.Hit then NewSelectedPointId = index end
						end
					end
				end

				tool.SelectedPointId = NewSelectedPointId
				tool.RangePoints = NewRangePoints
			end)
		end

		self:UpdateControlPanel()
	end
	
	function TOOL:AddNode()
		local tr = self:GetTraceInfo()
		if not tr.Hit then return end

		local isAutoCreated = false
		local countPoints = 0
		local endNode, previewNode, newNode

		if self.CreateSelectedNode then
			local startPos = self.CreateSelectedNode.position
			local endPos = tr.HitPos + Vector(0, 0, 10)

			if self.SelectedPointId ~= -1 then
				endNode = BGN_NODE:GetNodeByIndex(self.SelectedPointId)
				if endNode then
					endPos  = endNode.position
				end
			end

			local points = self:AutoCreatePoints(startPos, endPos)
			if #points == 0 then
				if endNode then
					endNode:AddLink(self.CreateSelectedNode, 'walk')
					isAutoCreated = true
				end
			else
				previewNode = self.CreateSelectedNode
				countPoints = #points
				for i = 1, countPoints do

					if i == countPoints and endNode and previewNode then
						endNode:AddLink(previewNode, 'walk')
					else
						local pos = points[i]
						local node = BGN_NODE:Instance(pos)
						BGN_NODE:AddNodeToMap(node)

						if previewNode then
							node:AddLink(previewNode, 'walk')
						end

						self:ConstructParent(node)
						previewNode = node
					end
				end
				
				isAutoCreated = true
			end
		end

		if not isAutoCreated then
			newNode = BGN_NODE:Instance(tr.HitPos)
			BGN_NODE:AddNodeToMap(newNode)

			if self.CreateSelectedNode then
				newNode:AddLink(self.CreateSelectedNode, 'walk')
			end

			self:ConstructParent(newNode)

			newNode.position = newNode.position + Vector(0, 0, 10)
		end

		if self.CreateSelectedNode and countPoints == 0 then
			self.CreateSelectedNode = endNode or previewNode or newNode
		else
			self.CreateSelectedNode = endNode or previewNode
		end

		surface.PlaySound('common/wpn_select.wav')
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

	function TOOL:AutoCreatePoints(startPos, endPos)
		local autoalignment = GetConVar('bgn_tool_point_editor_autoalignment'):GetBool()
		local points = {}
		local dist = startPos:Distance(endPos)
		local max = math.floor(dist / 250)
		local limit = 1 / max
		if max >= 1 then
			local oldZ = startPos.z
			for i = 1, max do
				local fraction = limit * i
				local output = LerpVector(fraction, startPos, endPos)

				if autoalignment then
					local tr = util.TraceLine({
						start = Vector(output.x, output.y, oldZ) + Vector(0, 0, 100),
						endpos = output - Vector(0, 0, 500),
						filter = function(ent)
							if ent:IsWorld() then
								return true
							end
						end
					})

					if not tr.Hit then return {} end
					oldZ = output.z
					table.insert(points, tr.HitPos + Vector(0, 0, 10))
				else
					table.insert(points, output)
				end
			end
		end
		return points
	end
	
	function TOOL:ClearPoints()
		BGN_NODE:ClearNodeMap()
		self.CreateSelectedNode = nil
		surface.PlaySound('common/wpn_denyselect.wav')
	end

	function TOOL:ConstructParent(node)
		local is_autoparent = GetConVar('bgn_tool_point_editor_autoparent'):GetBool()
		
		for _, anotherNode in ipairs(BGN_NODE:GetNodeMap()) do
			if anotherNode ~= node then
				local pos = anotherNode:GetPos()
				
				if not anotherNode:HasParent(node) and node:CheckDistanceLimitToNode(pos) 
					and node:CheckHeightLimitToNode(pos) and node:CheckTraceSuccessToNode(pos)
				then
					anotherNode:AddParentNode(node)

					if is_autoparent then
						anotherNode:AddLink(node, 'walk')
					end
				end
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
			if self.LastNodeRemover then
				surface.DrawText(language.GetPhrase('tool.bgn_point_editor.vis.last_remover')
					.. ' - ' .. tostring(BGN_NODE:CountNodesOnMap()))
			else
				surface.DrawText('#tool.bgn_point_editor.vis.remover')
			end
		elseif type == 'linker' then
			if self.LinkFullParents then
				surface.DrawText('#tool.bgn_point_editor.vis.linker_parents')
			else
				surface.DrawText('#tool.bgn_point_editor.vis.linker')
			end
		elseif type == 'parents_cleaner' then
			if self.LinkFullParents then
				surface.DrawText('#tool.bgn_point_editor.vis.linker_cleaner_parents')
			else
				surface.DrawText('#tool.bgn_point_editor.vis.linker_cleaner')
			end
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
			["Label"] = "#tool.bgn_point_editor.pnl.clear_points",
			["Command"] = "cl_bgn_clear_tool_points",
		})

		Panel:AddControl('CheckBox', {
			Label = '#tool.bgn_point_editor.autoparent',
			Command = 'bgn_tool_point_editor_autoparent' 
		}); Panel:AddControl('Label', {
			Text = '#tool.bgn_point_editor.autoparent.desc'
		})

		Panel:AddControl('CheckBox', {
			Label = '#tool.bgn_point_editor.autoalignment',
			Command = 'bgn_tool_point_editor_autoalignment' 
		}); Panel:AddControl('Label', {
			Text = '#tool.bgn_point_editor.autoalignment.desc'
		})

		Panel:AddControl("Button", {
			["Label"] = "#tool.bgn_point_editor.pnl.reconstruct_parents",
			["Command"] = "cl_tool_point_editor_reconstruct_parents",
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

		Panel:AddControl('CheckBox', {
			Label = '#tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents',
			Command = 'bgn_tool_point_editor_show_parents' 
		}); Panel:AddControl('Label', {
			Text = '#tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents.desc'
		})
	end
	
	local en_lang = {
		['tool.bgn_point_editor.name'] = 'Points Editor',
		['tool.bgn_point_editor.desc'] = 'Tool for editing the points of movement of background NPCs.',
		['tool.bgn_point_editor.0'] = 'Left click - Interaction. Right click - Change tool type. Reload - Switching submodes.',
		['tool.bgn_point_editor.pnl.load_points'] = 'Load points',
		['tool.bgn_point_editor.pnl.save_points'] = 'Save points',
		['tool.bgn_point_editor.pnl.reconstruct_parents'] = 'Re-create points links',
		['tool.bgn_point_editor.autoparent'] = 'Auto parent',
		['tool.bgn_point_editor.autoparent.desc'] = 'Description: enable automatic creation of links.',
		['tool.bgn_point_editor.autoalignment'] = 'Auto-height',
		['tool.bgn_point_editor.autoalignment.desc'] = 'Description: enable automatic height alignment.',
		['tool.bgn_point_editor.pnl.z_limit'] = 'Height limit between points',
		['tool.bgn_point_editor.pnl.z_limit.desc'] = 'Description: Height limit between points. Used to correctly define child points.',
		['tool.bgn_point_editor.vis.good_place'] = 'Good place',
		['tool.bgn_point_editor.vis.lock_pos'] = 'Too far from other points',
		['tool.bgn_point_editor.vis.creator'] = 'Creating points',
		['tool.bgn_point_editor.vis.remover'] = 'Deleting a selected point',
		['tool.bgn_point_editor.vis.last_remover'] = 'Delete last point',
		['tool.bgn_point_editor.vis.linker'] = 'Linker node',
		['tool.bgn_point_editor.vis.linker_parents'] = 'Linker parents node',
		['tool.bgn_point_editor.vis.linker_cleaner'] = 'Cleaner node links',
		['tool.bgn_point_editor.vis.linker_cleaner_parents'] = 'Cleaner parents node links',
		['tool.bgn_point_editor.vis.selected'] = 'Selected',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance'] = 'Distance to draw points',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'] = 'Description: sets the maximum distance to draw points in edit mode.',
		['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents'] = 'Show global connections',
		['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents.desc'] = 'Description: shows global (white) connections that are used by NPCs in special cases. For example - escape from the attacker.',
		['tool.bgn_point_editor.pnl.clear_points'] = 'Clear all points (Local)',
	}

	local ru_lang = {
		['tool.bgn_point_editor.name'] = 'Редактор точек',
		['tool.bgn_point_editor.desc'] = 'Инструмент для редактирования точек перемещения фоновых НПС.',
		['tool.bgn_point_editor.0'] = 'Левый клик - Взаимодействие. Правый клик - Сменить тип инструмента. Перезарядка - Переключение подрежимов.',
		['tool.bgn_point_editor.pnl.load_points'] = 'Загрузить точки',
		['tool.bgn_point_editor.pnl.save_points'] = 'Сохранить точки',
		['tool.bgn_point_editor.pnl.reconstruct_parents'] = 'Пересоздать связи точек',
		['tool.bgn_point_editor.autoparent'] = 'Авто-связка',
		['tool.bgn_point_editor.autoparent.desc'] = 'Описание: включить автоматическое создание связей.',
		['tool.bgn_point_editor.autoalignment'] = 'Авто-высота',
		['tool.bgn_point_editor.autoalignment.desc'] = 'Описание: включить автоматическое выравнивание по высоте.',
		['tool.bgn_point_editor.pnl.z_limit'] = 'Ограничение высоты между точками',
		['tool.bgn_point_editor.pnl.z_limit.desc'] = 'Описание: Ограничение высоты между точками. Используется для правильного определения дочерних точек.',
		['tool.bgn_point_editor.vis.good_place'] = 'Хорошая позиция',
		['tool.bgn_point_editor.vis.lock_pos'] = 'Слишком далеко от других точек',
		['tool.bgn_point_editor.vis.creator'] = 'Создание точек',
		['tool.bgn_point_editor.vis.remover'] = 'Удаление выбранной точки',
		['tool.bgn_point_editor.vis.last_remover'] = 'Удалить последнюю точку',
		['tool.bgn_point_editor.vis.linker'] = 'Соединитель',
		['tool.bgn_point_editor.vis.linker_parents'] = 'Соединитель родительских нод',
		['tool.bgn_point_editor.vis.linker_cleaner'] = 'Очиститель связей',
		['tool.bgn_point_editor.vis.linker_cleaner_parents'] = 'Очиститель родительских связей',
		['tool.bgn_point_editor.vis.selected'] = 'Выбрано',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance'] = 'Дистанция прорисовки точек',
		['tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'] = 'Описание: устанавливает максимальное расстояние отрисовки точек в режиме редактирования.',
		['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents'] = 'Показать глобальные связи',
		['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents.desc'] = 'Описание: показывает глобальные (белые) соединения, которые используются НПС в особых случаях. Например - побег от нападавшего.',
		['tool.bgn_point_editor.pnl.clear_points'] = 'Очистить все точки (Локально)',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end

	local clr = Color(255, 225, 0, 200)
	local clr_green = Color(72, 232, 9, 200)
	local clr_link = Color(255, 0, 0)
	local clr_link_alpha = Color(255, 0, 0, 50)
	local clr_point = Color(255, 23, 23, 200)
	local clr_point_notlinks = Color(53, 53, 240, 200)
	local vec_20 = Vector(0, 0, 20)
	local color_white = Color(255, 255, 255)
	local color_black = Color(0, 0, 0)
	local clr_good = Color(0, 255, 0, 200)
	local clr_bad = Color(255, 0, 0, 200)
	local clr_parent = Color(255, 255, 255, 200)
	local clr_parent_alpha = Color(255, 255, 255, 50)
	local clr_future = Color(79, 224, 183, 200)

	local function GetCameraAngle()
		local cam_angle = LocalPlayer():EyeAngles()
		cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
		cam_angle:RotateAroundAxis(cam_angle:Right(), 90)
		return cam_angle
	end

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRenderPoints', function()
		if not SLibraryIsLoaded then return end

		local tool = LocalPlayer():slibGetActiveTool('bgn_point_editor')
      if not tool then return end

		local is_show_global_nodes = GetConVar('bgn_tool_point_editor_show_parents'):GetBool()
		local count = #tool.RangePoints

		if count ~= 0 then
			local cam_angle = GetCameraAngle()
			local IsDrawingParentsNode = {}

			render.SetColorMaterial()

			for i = 1, count do
				local value = tool.RangePoints[i]
				local index = value.index
				local node = value.node
				table.insert(IsDrawingParentsNode, node)

				local pos = node:GetPos()

				for _, parentNode in ipairs(node.parents) do
					if not array.HasValue(IsDrawingParentsNode, parentNode) then
						if node:HasLink(parentNode, 'walk') then
							if value.behindTheWall then
								render.DrawLine(pos, parentNode:GetPos(), clr_link_alpha)
							else
								render.DrawLine(pos, parentNode:GetPos(), clr_link)
							end
						elseif is_show_global_nodes then
							if value.behindTheWall then
								render.DrawLine(pos, parentNode:GetPos(), clr_parent_alpha)
							else
								render.DrawLine(pos, parentNode:GetPos(), clr_parent)
							end
						end
					end
				end

				if index == tool.SelectedPointId and tool.CreateSelectedNode then
					render.DrawSphere(node.position, 10, 20, 20, clr_green)
				else
					if #node:GetLinks('walk') == 0 then
						render.DrawSphere(pos, 10, 30, 30, clr_point_notlinks)
					else
						render.DrawSphere(pos, 10, 30, 30, clr_point)
					end
				end

				cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
					if index == tool.SelectedPointId then
						local linksCount = table.Count(node:GetLinks('walk'))
						if linksCount ~= 0 then
							draw.SimpleTextOutlined('Walk links - ' .. linksCount, 
								"TargetID", 0, 0, color_white, 
								TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
						end

						draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.selected', 
							"TargetID", 0, 25, color_white, 
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
					end
				cam.End3D2D()
			end
		end
	end)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorDrawCreatorPoint', function()
		if not SLibraryIsLoaded then return end
		
		local tool = LocalPlayer():slibGetActiveTool('bgn_point_editor')
      if not tool or tool:GetCurrentType() ~= 'creator' then return end

		local tr = tool:GetTraceInfo()
		if tr.Hit and tool:GetCurrentType() == 'creator' then
			local tracePos = tr.HitPos
			local tooFar = true
			local futurePoints = {}

			if BGN_NODE:CountNodesOnMap() == 0 then
				tooFar = false
			else
				local nodes = BGN_NODE:GetNodeMap()
				for i = 1, #nodes do
					local node = nodes[i]
					if node:CheckDistanceLimitToNode(tracePos) and node:CheckHeightLimitToNode(tracePos) 
						and node:CheckTraceSuccessToNode(tracePos)
					then
						tooFar = false
						table.insert(futurePoints, node)
					end
				end
			end

			if tooFar and not tool.CreateSelectedNode then
				local cam_angle = GetCameraAngle()

				render.SetColorMaterial()
				render.DrawSphere(tracePos, 10, 20, 20, clr)
				cam.Start3D2D(tracePos + vec_20, cam_angle, 0.9)
					draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.lock_pos', 
						"TargetID", 0, 0, color_white, 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				cam.End3D2D()
			else
				if tool.SelectedPointId == -1 then
					local cam_angle = GetCameraAngle()

					render.SetColorMaterial()
					render.DrawSphere(tracePos, 10, 20, 20, clr_green)
					cam.Start3D2D(tracePos + vec_20, cam_angle, 0.9)
						draw.SimpleTextOutlined('#tool.bgn_point_editor.vis.good_place', 
							"TargetID", 0, 0, color_white, 
							TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
					cam.End3D2D()

					for _, futureNode in ipairs(futurePoints) do
						render.DrawLine(tracePos, futureNode:GetPos(), clr_future)
					end
				end
			end
		end
	end)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRenderLinkerPoints', function()
		if not SLibraryIsLoaded then return end
		
		local tool = LocalPlayer():slibGetActiveTool('bgn_point_editor')
      if not tool or not tool.LinkerNode then return end

		render.SetColorMaterial()
		render.DrawSphere(tool.LinkerNode.position, 10, 30, 30, clr_green)

		local tr = tool:GetTraceInfo()
		if tr.Hit then
			if tool.SelectedPointId ~= -1 and tool.LinkerNode.position:DistToSqr(tr.HitPos) <= 250000 then
				local node = BGN_NODE:GetNodeByIndex(tool.SelectedPointId)
				render.DrawSphere(node.position, 10, 30, 30, clr_good)
				render.DrawLine(tool.LinkerNode.position, node.position, clr_good)
			else
				render.DrawLine(tool.LinkerNode.position, tr.HitPos, clr_bad)
				render.DrawSphere(tool.LinkerNode.position, 10, 30, 30, clr_bad)
			end
		end
	end)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRenderAutoparentsPoints', function()
		if not SLibraryIsLoaded then return end
		
		local tool = LocalPlayer():slibGetActiveTool('bgn_point_editor')
      if not tool or not tool.CreateSelectedNode or tool:GetCurrentType() ~= 'creator' then return end

		local tr = tool:GetTraceInfo()
		if not tr.Hit then return end

		local is_autoparent = GetConVar('bgn_tool_point_editor_autoparent'):GetBool()
		local startPos = tool.CreateSelectedNode.position
		local endPos = tr.HitPos
		local endNode

		if tool.SelectedPointId ~= -1 then
			endNode = BGN_NODE:GetNodeByIndex(tool.SelectedPointId)
			if endNode then
				endPos = endNode.position
			end
		end

		render.SetColorMaterial()
		render.DrawSphere(startPos, 10, 30, 30, clr_good)

		local points = tool:AutoCreatePoints(startPos, endPos)
		if #points == 0 and endNode then
			render.DrawLine(startPos, endPos, clr_good)
		else
			do
				local startPos = startPos
				local endPos = endPos
				local countPoints = #points

				for i = 1, countPoints do
					local pos = points[i]
					render.DrawLine(startPos, pos, clr_good)

					if i ~= countPoints then
						render.DrawSphere(pos, 10, 30, 30, clr_good)

						if is_autoparent then
							for _, value in ipairs(tool.RangePoints) do
								local node = value.node
								if node:CheckDistanceLimitToNode(pos) and node:CheckHeightLimitToNode(pos) 
									and node:CheckTraceSuccessToNode(pos)
								then
									render.DrawLine(pos, node:GetPos(), clr_future)
								end
							end
						end
					end

					startPos = pos
				end

				render.DrawLine(startPos, endPos, clr_good)
			end
		end
	end)
end