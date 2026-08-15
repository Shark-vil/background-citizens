TOOL.Category = 'Background NPCs'
TOOL.Name = '#tool.bgn_spawn_area.name'
TOOL.StartPoint = nil
TOOL.EndPoint = nil

--[[
	This tool only places the two corner points of a zone (world clicks or
	//pos1 //pos2 chat commands) and lets the player save/load/remove named
	zones. All the actual "what spawns here, how much, what's blocked" logic
	and storage lives server-side in bgNPC:GetSpawnAreas()/SetSpawnArea()/etc.
	(background_npcs_core/modules/spawner/actors/sv_zone_spawner.lua) - this
	file is just the editor.
--]]

local ACTOR_MODE_DEFAULT = 'default'
local ACTOR_MODE_BLOCKED = 'blocked'
local ACTOR_MODE_BOOSTED = 'boosted'

local function ResetSpawnArea(tool)
	if not tool then return end

	tool.StartPoint = nil
	tool.EndPoint = nil

	snet.Invoke('cl_tool_bgn_spawn_area_reset', tool:GetOwner())
end

local SendAreaListTo

if SERVER then
	hook.Add('PlayerButtonDown', 'BGN_StartKeyPadDivide', function(ply, button)
		if (button ~= 60 and button ~= 47) or not IsFirstTimePredicted() then return end
		snet.Invoke('BGN_ClientOpenCommandChat', ply)
	end)

	hook.Add('PlayerSay', 'BGN_Tool_SpawnArea', function(ply, text)
		local tool = ply:slibGetActiveTool('bgn_spawn_area')
		if not tool then return end

		local isPosOne = string.StartWith(text, '//pos1')
		local isPosTwo = string.StartWith(text, '//pos2')

		if not isPosOne and not isPosTwo then return end

		if isPosOne then
			tool.StartPoint = ply:GetPos()
		elseif isPosTwo then
			tool.EndPoint = ply:GetPos()
		end

		snet.Invoke('cl_tool_bgn_spawn_area_update_points', ply, tool.StartPoint, tool.EndPoint)

		return false
	end)

	function SendAreaListTo(ply)
		local list = {}

		for areaName, area in pairs(bgNPC:GetSpawnAreas()) do
			table.insert(list, {
				name = areaName,
				startPoint = area.startPoint,
				endPoint = area.endPoint
			})
		end

		snet.Invoke('cl_tool_bgn_spawn_area_sync_areas', ply, list)
	end

	snet.Callback('sv_tool_bgn_spawn_area_new', function(ply)
		ResetSpawnArea(ply:GetTool('bgn_spawn_area'))
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_list', function(ply)
		SendAreaListTo(ply)
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_get', function(ply, areaName)
		local area = bgNPC:GetSpawnArea(areaName)
		if not area then return end

		local tool = ply:GetTool('bgn_spawn_area')
		if not tool then return end

		tool.StartPoint = area.startPoint
		tool.EndPoint = area.endPoint

		snet.Invoke('cl_tool_bgn_spawn_area_load', ply, tool.StartPoint, tool.EndPoint, areaName, area.actors)
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_remove', function(ply, areaName)
		if not isstring(areaName) or #areaName == 0 then return end

		if bgNPC:RemoveSpawnArea(areaName) then
			ResetSpawnArea(ply:GetTool('bgn_spawn_area'))
			SendAreaListTo(ply)
		end
	end).Protect()

	snet.Callback('sv_tool_bgn_spawn_area_save', function(ply, areaName, actors, startPoint, endPoint)
		if not isstring(areaName) or #string.Trim(areaName) == 0 then return end
		if not isvector(startPoint) or not isvector(endPoint) then return end

		local area = bgNPC:SetSpawnArea(areaName, startPoint, endPoint, actors)
		if not area then return end

		local tool = ply:GetTool('bgn_spawn_area')
		if tool then
			tool.StartPoint = area.startPoint
			tool.EndPoint = area.endPoint
		end

		SendAreaListTo(ply)
	end).Protect()
end

function TOOL:Think()
	if self.FirstLoad then return end

	if SERVER then
		SendAreaListTo(self:GetOwner())
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
	snet.Callback('BGN_ClientOpenCommandChat', function()
		chat.Open(1)
	end)

	local function AddLanguage(name, text)
		language.Add('tool.bgn_spawn_area.' .. name, text)
	end

	AddLanguage('name', 'Spawn Area')
	AddLanguage('desc', 'Creates NPC spawn/no-spawn zones on the map')
	AddLanguage('left', 'First click sets the start corner, second click sets the end corner. Right click resets. Open the Zone Manager to configure which actors spawn inside.')

	-- Client-side cache of the tool's current editing state. This is the single
	-- source of truth used by both the CPanel and the standalone Zone Manager
	-- frame below, kept in sync with the server via snet callbacks.
	local state = {
		startPoint = nil,
		endPoint = nil,
		areaName = '',
		actors = {}, -- [actorType] = { mode = ..., count = ... }
		areaList = {} -- [areaName] = { startPoint = Vector, endPoint = Vector }
	}

	local mode_labels = {
		[ACTOR_MODE_DEFAULT] = 'Default',
		[ACTOR_MODE_BLOCKED] = 'Blocked',
		[ACTOR_MODE_BOOSTED] = 'Boosted'
	}

	local mode_order = { ACTOR_MODE_DEFAULT, ACTOR_MODE_BLOCKED, ACTOR_MODE_BOOSTED }

	local on_state_updated = {}

	local function NotifyStateUpdated()
		for _, callback in pairs(on_state_updated) do
			callback()
		end
	end

	-- Fired on plain corner-point placement (world click / //pos1 //pos2) - only
	-- ever touches the two points, never the loaded zone's name/actor rules, so
	-- nudging a corner doesn't wipe out whatever's already configured for it.
	snet.Callback('cl_tool_bgn_spawn_area_update_points', function(_, startPoint, endPoint)
		state.startPoint = startPoint
		state.endPoint = endPoint

		NotifyStateUpdated()
	end)

	-- Fired when an existing zone is loaded into the tool (full replace).
	snet.Callback('cl_tool_bgn_spawn_area_load', function(_, startPoint, endPoint, areaName, actors)
		state.startPoint = startPoint
		state.endPoint = endPoint
		state.areaName = areaName or ''
		state.actors = {}

		if actors then
			for actorType, entry in pairs(actors) do
				if istable(entry) then
					state.actors[actorType] = { mode = entry.mode or ACTOR_MODE_DEFAULT, count = entry.count or 1 }
				end
			end
		end

		NotifyStateUpdated()
	end)

	-- Fired on right-click / "New zone" - clears everything back to a blank slate.
	snet.Callback('cl_tool_bgn_spawn_area_reset', function()
		state.startPoint = nil
		state.endPoint = nil
		state.areaName = ''
		state.actors = {}

		NotifyStateUpdated()
	end)

	snet.Callback('cl_tool_bgn_spawn_area_sync_areas', function(_, list)
		state.areaList = {}

		for _, area in ipairs(list or {}) do
			state.areaList[area.name] = { startPoint = area.startPoint, endPoint = area.endPoint }
		end

		NotifyStateUpdated()
	end)

	local function RequestNewArea()
		state.areaName = ''
		state.actors = {}
		snet.InvokeServer('sv_tool_bgn_spawn_area_new')
	end

	local function RequestLoadArea(areaName)
		snet.InvokeServer('sv_tool_bgn_spawn_area_get', areaName)
	end

	local function RequestRemoveArea(areaName)
		snet.InvokeServer('sv_tool_bgn_spawn_area_remove', areaName)
	end

	local function RequestSaveArea(areaName, actors)
		if not state.startPoint or not state.endPoint then return false end

		areaName = string.Trim(areaName or '')
		if #areaName == 0 then return false end

		state.areaName = areaName
		state.actors = actors or {}

		snet.InvokeServer('sv_tool_bgn_spawn_area_save', areaName, actors, state.startPoint, state.endPoint)
		return true
	end

	local function SortedAreaNames()
		local names = {}
		for areaName in pairs(state.areaList) do
			table.insert(names, areaName)
		end
		table.sort(names)
		return names
	end

	----------------------------------------------------------------------
	-- Standalone Zone Manager - full per-actor-type editor for the zone
	-- currently loaded into the tool (state.areaName/actors).
	----------------------------------------------------------------------

	local ManagerFrame

	local function OpenZoneManager()
		if IsValid(ManagerFrame) then
			ManagerFrame:Close()
		end

		local frame = vgui.Create('DFrame')
		frame:SetSize(760, 560)
		frame:SetMinWidth(620)
		frame:SetMinHeight(420)
		frame:SetTitle('Background NPCs - Zone Manager')
		frame:SetSizable(true)
		frame:Center()
		frame:MakePopup()
		ManagerFrame = frame

		local left = vgui.Create('DPanel', frame)
		left:Dock(LEFT)
		left:SetWide(200)
		left:DockMargin(0, 0, 4, 0)
		left.Paint = function(_, w, h)
			surface.SetDrawColor(40, 40, 40, 255)
			surface.DrawRect(0, 0, w, h)
		end

		local zoneList = vgui.Create('DListView', left)
		zoneList:Dock(FILL)
		zoneList:DockMargin(4, 4, 4, 4)
		zoneList:SetMultiSelect(false)
		zoneList:AddColumn('Saved zones')

		local newButton = vgui.Create('DButton', left)
		newButton:Dock(BOTTOM)
		newButton:DockMargin(4, 0, 4, 4)
		newButton:SetText('New zone')
		newButton.DoClick = RequestNewArea

		local removeButton = vgui.Create('DButton', left)
		removeButton:Dock(BOTTOM)
		removeButton:DockMargin(4, 0, 4, 4)
		removeButton:SetText('Delete selected zone')
		removeButton.DoClick = function()
			if not state.areaName or #state.areaName == 0 then return end
			RequestRemoveArea(state.areaName)
		end

		local right = vgui.Create('DPanel', frame)
		right:Dock(FILL)
		right.Paint = function(_, w, h)
			surface.SetDrawColor(30, 30, 30, 255)
			surface.DrawRect(0, 0, w, h)
		end

		local nameEntry = vgui.Create('DTextEntry', right)
		nameEntry:Dock(TOP)
		nameEntry:DockMargin(6, 6, 6, 4)
		nameEntry:SetPlaceholderText('Unique zone name')

		local pointsLabel = vgui.Create('DLabel', right)
		pointsLabel:Dock(TOP)
		pointsLabel:DockMargin(8, 0, 6, 6)
		pointsLabel:SetTall(20)
		pointsLabel:SetTextColor(color_white)

		local helpLabel = vgui.Create('DLabel', right)
		helpLabel:Dock(TOP)
		helpLabel:DockMargin(8, 0, 6, 6)
		helpLabel:SetTall(32)
		helpLabel:SetWrap(true)
		helpLabel:SetAutoStretchVertical(true)
		helpLabel:SetTextColor(Color(190, 190, 190))
		helpLabel:SetText('"Default" = normal map-wide rules. "Blocked" = never spawns/teleports inside this zone. "Boosted" = the zone actively keeps N of this type alive inside its bounds, on top of anything spawning elsewhere - actors that wander off despawn under the usual distance/visibility rules like any other actor.')

		local scroll = vgui.Create('DScrollPanel', right)
		scroll:Dock(FILL)
		scroll:DockMargin(4, 0, 4, 4)

		local rows = {}

		local function BuildRows()
			scroll:Clear()
			rows = {}

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				local entry = state.actors[actorType]
				local initialMode = entry and entry.mode or ACTOR_MODE_DEFAULT
				local initialCount = entry and entry.count or 1

				local row = vgui.Create('DPanel', scroll)
				row:Dock(TOP)
				row:SetTall(28)
				row:DockMargin(2, 2, 2, 0)
				row.Paint = function(_, w, h)
					surface.SetDrawColor(45, 45, 45, 255)
					surface.DrawRect(0, 0, w, h)
				end

				local label = vgui.Create('DLabel', row)
				label:Dock(LEFT)
				label:SetWide(220)
				label:SetContentAlignment(4)
				label:DockMargin(6, 0, 0, 0)
				label:SetTextColor(color_white)
				label:SetText(actorData.name or actorType)

				local slider = vgui.Create('DNumSlider', row)
				slider:Dock(FILL)
				slider:DockMargin(6, 0, 6, 0)
				slider:SetText('Count')
				slider:SetMin(1)
				slider:SetMax(50)
				slider:SetDecimals(0)
				slider:SetValue(initialCount)
				slider:SetEnabled(initialMode == ACTOR_MODE_BOOSTED)

				local combo = vgui.Create('DComboBox', row)
				combo:Dock(RIGHT)
				combo:SetWide(110)
				combo:DockMargin(0, 3, 6, 3)

				for _, mode in ipairs(mode_order) do
					combo:AddChoice(mode_labels[mode], mode)
				end

				combo.OnSelect = function(_, _, _, data)
					slider:SetEnabled(data == ACTOR_MODE_BOOSTED)
				end

				for id = 1, #mode_order do
					if mode_order[id] == initialMode then
						combo:ChooseOptionID(id)
						break
					end
				end

				rows[actorType] = { combo = combo, slider = slider }
			end
		end

		local function RefreshZoneList()
			zoneList:Clear()
			for _, areaName in ipairs(SortedAreaNames()) do
				zoneList:AddLine(areaName)
			end
		end

		zoneList.OnRowSelected = function(_, _, pnl)
			RequestLoadArea(pnl:GetColumnText(1))
		end

		local buttons = vgui.Create('DPanel', right)
		buttons:Dock(BOTTOM)
		buttons:SetTall(34)
		buttons.Paint = nil

		local saveButton = vgui.Create('DButton', buttons)
		saveButton:Dock(FILL)
		saveButton:DockMargin(6, 4, 6, 4)
		saveButton:SetText('Save zone')
		saveButton.DoClick = function()
			local areaName = string.Trim(nameEntry:GetValue())
			if #areaName == 0 then
				surface.PlaySound('buttons/button10.wav')
				return
			end

			local actors = {}
			for actorType, widgets in pairs(rows) do
				local mode = widgets.combo:GetOptionData(widgets.combo:GetSelectedID()) or ACTOR_MODE_DEFAULT
				actors[actorType] = { mode = mode, count = math.Round(widgets.slider:GetValue()) }
			end

			RequestSaveArea(areaName, actors)
		end

		local function Refresh()
			nameEntry:SetValue(state.areaName or '')

			if state.startPoint and state.endPoint then
				pointsLabel:SetText('Points: ' .. tostring(state.startPoint) .. '  ->  ' .. tostring(state.endPoint))
			else
				pointsLabel:SetText('Points: not set - left click twice in the world (or use //pos1 //pos2) while this tool is equipped.')
			end

			BuildRows()
			RefreshZoneList()
		end

		on_state_updated['manager'] = Refresh

		frame.OnClose = function()
			on_state_updated['manager'] = nil
		end

		Refresh()

		snet.InvokeServer('sv_tool_bgn_spawn_area_list')
	end

	----------------------------------------------------------------------
	-- CPanel (Q menu) - quick zone list + entry point to the full manager.
	----------------------------------------------------------------------

	function TOOL.BuildCPanel(CPanel)
		local panel = controlpanel.Get('bgn_spawn_area')
		panel:ClearControls()

		local helpLabel = vgui.Create('DLabel', panel)
		helpLabel:Dock(TOP)
		helpLabel:DockMargin(5, 5, 5, 5)
		helpLabel:SetWrap(true)
		helpLabel:SetAutoStretchVertical(true)
		helpLabel:SetText(language.GetPhrase('tool.bgn_spawn_area.left'))

		local pointsLabel = vgui.Create('DLabel', panel)
		pointsLabel:Dock(TOP)
		pointsLabel:DockMargin(5, 0, 5, 5)
		pointsLabel:SetWrap(true)
		pointsLabel:SetAutoStretchVertical(true)

		local areaList = vgui.Create('DListView', panel)
		areaList:SetSize(0, 220)
		areaList:Dock(TOP)
		areaList:DockMargin(5, 5, 5, 5)
		areaList:SetMultiSelect(false)
		areaList:AddColumn('Saved zones')
		areaList.OnRowSelected = function(_, _, pnl)
			RequestLoadArea(pnl:GetColumnText(1))
		end

		local newButton = vgui.Create('DButton', panel)
		newButton:Dock(TOP)
		newButton:DockMargin(5, 0, 5, 5)
		newButton:SetText('New zone')
		newButton.DoClick = RequestNewArea

		local removeButton = vgui.Create('DButton', panel)
		removeButton:Dock(TOP)
		removeButton:DockMargin(5, 0, 5, 5)
		removeButton:SetText('Delete selected zone')
		removeButton.DoClick = function()
			if not state.areaName or #state.areaName == 0 then return end
			RequestRemoveArea(state.areaName)
		end

		local resaveButton = vgui.Create('DButton', panel)
		resaveButton:Dock(TOP)
		resaveButton:DockMargin(5, 0, 5, 5)
		resaveButton:SetText('Save current points to loaded zone')
		resaveButton.DoClick = function()
			if not state.areaName or #state.areaName == 0 then return end
			RequestSaveArea(state.areaName, state.actors)
		end

		local managerButton = vgui.Create('DButton', panel)
		managerButton:Dock(TOP)
		managerButton:DockMargin(5, 10, 5, 5)
		managerButton:SetText('Open Zone Manager (configure actors)')
		managerButton.DoClick = OpenZoneManager

		local function Refresh()
			areaList:Clear()
			for _, areaName in ipairs(SortedAreaNames()) do
				areaList:AddLine(areaName)
			end

			if state.startPoint and state.endPoint then
				pointsLabel:SetText('Current zone: ' .. (state.areaName ~= '' and state.areaName or '(unsaved)'))
			else
				pointsLabel:SetText('No points placed yet.')
			end
		end

		on_state_updated['cpanel'] = Refresh

		Refresh()

		snet.InvokeServer('sv_tool_bgn_spawn_area_list')
	end

	----------------------------------------------------------------------
	-- World overlay - draws the two picked points, the box being edited,
	-- and every saved zone (label + faint box) so admins can see what's
	-- already placed on the map while equipping the tool.
	----------------------------------------------------------------------

	local function InitDrawArea()
		local colorMaterial = Material('color')
		local colorFirstPoint = Color(51, 255, 0, 200)
		local colorSecondPoint = Color(255, 0, 0, 200)
		local colorArea = Color(214, 214, 214, 150)
		local colorAreaWireframe = Color(255, 255, 255, 218)
		local colorSavedAreaWireframe = Color(90, 170, 255, 160)

		hook.Add('PostDrawOpaqueRenderables', 'BGN_InitDrawArea', function()
			if not SLibraryIsLoaded then return end

			local tool = LocalPlayer():slibGetActiveTool('bgn_spawn_area')
			if not tool then return end

			render.SetColorMaterial()

			for areaName, area in pairs(state.areaList) do
				if areaName == state.areaName then continue end

				local center = (area.startPoint + area.endPoint) / 2
				local mins = center - area.startPoint
				local maxs = center - area.endPoint
				local rotation = Angle()

				render.SetMaterial(colorMaterial)
				render.DrawWireframeBox(center, rotation, mins, maxs, colorSavedAreaWireframe)
			end

			if state.startPoint then
				render.DrawSphere(state.startPoint, 15, 10, 10, colorFirstPoint)
			end

			if state.endPoint then
				render.DrawSphere(state.endPoint, 15, 10, 10, colorSecondPoint)
			end

			if state.startPoint and state.endPoint then
				local center = (state.startPoint + state.endPoint) / 2
				local mins = center - state.startPoint
				local maxs = center - state.endPoint
				local rotation = Angle()

				render.SetMaterial(colorMaterial)

				render.DrawWireframeBox(center, rotation, mins, maxs, colorAreaWireframe)
				render.DrawBox(center, rotation, mins, maxs, colorArea)
			end
		end)

		hook.Add('HUDPaint', 'BGN_DrawAreaLabels', function()
			local tool = LocalPlayer():slibGetActiveTool('bgn_spawn_area')
			if not tool then return end

			for areaName, area in pairs(state.areaList) do
				local center = (area.startPoint + area.endPoint) / 2
				local screenPos = center:ToScreen()
				if screenPos.visible then
					draw.SimpleTextOutlined(areaName, 'DermaDefaultBold', screenPos.x, screenPos.y, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
				end
			end
		end)
	end

	InitDrawArea()
end
