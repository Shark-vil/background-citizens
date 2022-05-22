TOOL.Category = 'Background NPCs'
TOOL.Name = '#tool.bgn_spawn_area.name'
TOOL.StartPoint = nil
TOOL.EndPoint = nil

local function ResetSpawnArea(tool)
	tool.StartPoint = nil
	tool.EndPoint = nil
	snet.Invoke('cl_tool_bgn_spawn_area_update_points', tool:GetOwner())
end

local filePath = 'background_npcs/spawn_area/' .. game.GetMap() .. '.dat'

if SERVER then
	do
		hook.Add('PlayerButtonDown', 'BGN_StartKeyPadDivide', function(ply, button)
			if (button ~= 60 and button ~= 47) or not IsFirstTimePredicted() then return end
			snet.Invoke('BGN_ClientOpenCommandChat', ply)
		end)
	end

	hook.Add('PlayerSay', 'BGN_Tool_SpawnArea', function(ply, text)
		local tool = ply:slibGetActiveTool('bgn_spawn_area')
		if not tool then return end

		local isPosOne = string.StartWith(text, '//pos1')
		local isPosTwo = string.StartWith(text, '//pos2')

		if not isPosOne and not isPosTwo then return end

		local toolData = ply:GetTool('bgn_spawn_area')

		if isPosOne then
			toolData.StartPoint = ply:GetPos()
		elseif isPosTwo then
			toolData.EndPoint = ply:GetPos()
		end

		snet.Invoke('cl_tool_bgn_spawn_area_update_points', tool:GetOwner(), tool.StartPoint, tool.EndPoint)

		return false
	end)

	if not file.Exists('background_npcs/spawn_area', 'DATA') then
		file.CreateDir('background_npcs/spawn_area')
	end

	if file.Exists(filePath, 'DATA') then
		if not file.Exists(filePath, 'DATA') then return end
		local readData = file.Read(filePath, 'DATA')
		local areaData = util.JSONToTable(readData)
		bgNPC.SpawnArea = areaData
	end

	snet.Callback('sv_tool_bgn_spawn_area_new', function(ply)
		ResetSpawnArea(ply:GetTool('bgn_spawn_area'))
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_get', function(ply, areaName)
		if not file.Exists(filePath, 'DATA') then return end
		local readData = file.Read(filePath, 'DATA')
		local areaData = util.JSONToTable(readData)
		if not areaData[areaName] then return end

		local tool = ply:GetTool('bgn_spawn_area')
		tool.StartPoint = areaData[areaName].startPoint
		tool.EndPoint = areaData[areaName].endPoint

		snet.Invoke('cl_tool_bgn_spawn_area_update_points', ply, tool.StartPoint, tool.EndPoint, areaName, areaData[areaName].actors)
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_remove', function(ply, areaName)
		if file.Exists(filePath, 'DATA') then
			local readData = file.Read(filePath, 'DATA')
			local areaData = util.JSONToTable(readData)
			areaData[areaName] = nil
			bgNPC.SpawnArea = areaData
			file.Write(filePath, util.TableToJSON(areaData, true))
			ResetSpawnArea(ply:GetTool('bgn_spawn_area'))
		end
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_save', function(ply, areaName, actors, startPoint, endPoint)
		local areaData = {}

		if file.Exists(filePath, 'DATA') then
			local readData = file.Read(filePath, 'DATA')
			areaData = util.JSONToTable(readData)
		end

		areaData[areaName] = {
			startPoint = startPoint,
			endPoint = endPoint,
			actors = actors
		}

		bgNPC.SpawnArea = areaData
		file.Write(filePath, util.TableToJSON(areaData, true))
	end).Protect()
end

function TOOL:Think()
	if self.FirstLoad then return end

	if file.Exists(filePath, 'DATA') then
		local readData = file.Read(filePath, 'DATA')
		local areaData = util.JSONToTable(readData)
		local areaTagList = {}

		for areaName in pairs(areaData) do
			table.insert(areaTagList, areaName)
		end

		snet.Invoke('cl_tool_bgn_spawn_area_sync_tags', self:GetOwner(), areaTagList)
	end

	self.FirstLoad = true
end

function TOOL:LeftClick(tr)
	if SERVER then
		if not self.StartPoint then
			self.StartPoint = tr.HitPos
		else
			self.EndPoint = tr.HitPos
		end

		snet.Invoke('cl_tool_bgn_spawn_area_update_points', self:GetOwner(), self.StartPoint, self.EndPoint)
	end

	return true
end

function TOOL:RightClick()
	if SERVER then
		ResetSpawnArea(self)
		return true
	end

	return false
end

if CLIENT then
	CreateClientConVar('cl_bgn_tool_bgn_spawn_area_tag_name', '', false)

	snet.Callback('BGN_ClientOpenCommandChat', function()
		chat.Open(1)
	end)

	for actorType in SortedPairs(bgNPC.cfg.actors) do
		CreateClientConVar('cl_bgn_tool_bgn_spawn_area_actor_' .. actorType, '0', false)
	end

	local _startPoint
	local _endPoint

	local function AddLanguage(name, text)
		language.Add('tool.bgn_spawn_area.' .. name, text)
	end

	local function InitLanguage()
		AddLanguage('name', 'Spawn Area')
		AddLanguage('desc', 'Creates a spawn area for NPCs')
		AddLanguage('left', 'Press the first time to set the start point, and the second time to set the end point.')
	end

	function TOOL.BuildCPanel(CPanel)
		InitLanguage()

		local cvarAreaTagName = GetConVar('cl_bgn_tool_bgn_spawn_area_tag_name')

		local panel = controlpanel.Get('bgn_spawn_area')
		panel:ClearControls()

		local areaTagName = vgui.Create('DTextEntry', panel)
		areaTagName:Dock(TOP)
		areaTagName:DockMargin(5, 5, 5, 5)
		areaTagName:SetPlaceholderText('Unique area tag name')
		areaTagName.OnEnter = function(self)
			cvarAreaTagName:SetString(self:GetValue())
		end

		local areaList = vgui.Create('DListView', panel)
		areaList:SetSize(0, 250)
		areaList:Dock(TOP)
		areaList:DockMargin(5, 5, 5, 5)
		areaList:SetMultiSelect(false)
		areaList:AddColumn('Name')
		areaList.OnRowSelected = function(lst, index, pnl)
			snet.InvokeServer('sv_tool_bgn_spawn_area_get', pnl:GetColumnText(1))
		end

		local actorsSpawnWhiteList = vgui.Create('DScrollPanel', panel)
		actorsSpawnWhiteList:SetSize(0, 250)
		actorsSpawnWhiteList:Dock(TOP)
		actorsSpawnWhiteList:DockMargin(10, 0, 10, 0)

		for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
			local cvarName = 'cl_bgn_tool_bgn_spawn_area_actor_' .. actorType
			local actorCheckBox = actorsSpawnWhiteList:Add('DCheckBoxLabel')
			actorCheckBox:Dock(TOP)
			actorCheckBox:SetText(actorData.name or actorType)
			actorCheckBox:SetConVar(cvarName)
			actorCheckBox:SetValue(GetConVar(cvarName):GetBool())
			actorCheckBox:SetDark(true)
		end

		local resetAreaButton = vgui.Create('DButton', panel)
		resetAreaButton:Dock(TOP)
		resetAreaButton:DockMargin(5, 5, 5, 5)
		resetAreaButton:SetText('New area')
		resetAreaButton.DoClick = function(self)
			snet.InvokeServer('sv_tool_bgn_spawn_area_new')
		end

		local saveAreaButton = vgui.Create('DButton', panel)
		saveAreaButton:Dock(TOP)
		saveAreaButton:DockMargin(5, 5, 5, 5)
		saveAreaButton:SetText('Save area')
		saveAreaButton.DoClick = function(self)
			if not _startPoint or not _endPoint then return end

			local areaName = cvarAreaTagName:GetString()
			if areaName and #string.Trim(areaName) ~= 0 then
				local existName = false

				for _, line in ipairs(areaList:GetLines()) do
					if line:GetValue(1) == areaName then
						existName = true
						break
					end
				end

				if not existName then
					areaList:AddLine(areaName)
				end
			end

			local actors = {}

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				local cvarName = 'cl_bgn_tool_bgn_spawn_area_actor_' .. actorType
				actors[actorType] = GetConVar(cvarName):GetBool()
			end

			snet.InvokeServer('sv_tool_bgn_spawn_area_save', areaName, actors, _startPoint, _endPoint)
		end

		local removeAreaButton = vgui.Create('DButton', panel)
		removeAreaButton:Dock(TOP)
		removeAreaButton:DockMargin(5, 5, 5, 5)
		removeAreaButton:SetText('Remove area')
		removeAreaButton.DoClick = function(self)
			local areaName = cvarAreaTagName:GetString()
			if areaName and #string.Trim(areaName) ~= 0 then
				snet.InvokeServer('sv_tool_bgn_spawn_area_remove', areaName)

				for lineIndex, line in ipairs(areaList:GetLines()) do
					if line:GetValue(1) == areaName then
						areaList:RemoveLine(lineIndex)
						break
					end
				end
			end
		end

		snet.Callback('cl_tool_bgn_spawn_area_sync_tags', function(_, areaTagList)
			for _, areaName in ipairs(areaTagList) do
				local notExist = true

				for _, line in ipairs(areaList:GetLines()) do
					if line:GetValue(1) == areaName then
						notExist = false
						break
					end
				end

				if notExist then
					areaList:AddLine(areaName)
				end
			end
		end)

		snet.Callback('cl_tool_bgn_spawn_area_update_points', function(_, startPoint, endPoint, areaName, actors)
			_startPoint = startPoint
			_endPoint = endPoint

			if areaName then
				areaTagName:SetValue(areaName)
				cvarAreaTagName:SetString(areaName)
			end

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				local cvarName = 'cl_bgn_tool_bgn_spawn_area_actor_' .. actorType

				if actors then
					for anotherActorType, boolValue in SortedPairs(actors) do
						if actorType == anotherActorType then
							GetConVar(cvarName):SetInt(boolValue and 1 or 0)
							goto skip
						end
					end
				end

				GetConVar(cvarName):SetInt(0)

				::skip::
			end
		end)
	end

	local function InitDrawArea()
		local colorMaterial = Material('color')
		local colorFirstPoint = Color(51, 255, 0, 200)
		local colorSecondPoint = Color(255, 0, 0, 200)
		local colorArea = Color(214, 214, 214, 150)
		local colorAreaWireframe = Color(255, 255, 255, 218)

		hook.Add('PostDrawOpaqueRenderables', 'BGN_InitDrawArea', function()
			if not SLibraryIsLoaded then return end

			local tool = LocalPlayer():slibGetActiveTool('bgn_spawn_area')
			if not tool then return end

			render.SetColorMaterial()

			if _startPoint then
				render.DrawSphere(_startPoint, 15, 10, 10, colorFirstPoint)
			end

			if _endPoint then
				render.DrawSphere(_endPoint, 15, 10, 10, colorSecondPoint)
			end

			if _startPoint and _endPoint then
				local center = (_startPoint + _endPoint) / 2
				local min = center - _startPoint
				local max = center - _endPoint
				local rotation = Angle()

				render.SetMaterial(colorMaterial)

				render.DrawWireframeBox(center, rotation, min, max, colorAreaWireframe)
				render.DrawBox(center, rotation, min, max, colorArea)
			end
		end)
	end

	InitDrawArea()
end