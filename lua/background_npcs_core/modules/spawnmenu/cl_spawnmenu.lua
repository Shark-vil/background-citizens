-- spawnmenu.AddCreationTab('Background NPCs', function()
-- 	local ctrl = vgui.Create('SpawnmenuContentPanel')
-- 	ctrl:CallPopulateHook('InitSpawnmenuBGN')
-- 	return ctrl
-- end, 'icon16/user_suit.png', 50)

CreateClientConVar('bgn_spawnmenu_default_spawner', '', false)

hook.Add('PopulateNPCs', 'BackgroundNPCs', function(pnlContent, tree)
	local node = tree:AddNode('Background NPCs', 'icon16/monkey.png')

	node.DoPopulate = function(self)
		if self.PropPanel then return end

		self.PropPanel = vgui.Create('ContentContainer', pnlContent)
		self.PropPanel:SetVisible(false)
		self.PropPanel:SetTriggerSpawnlistChange(false)

		for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
			local entity_class = ''

			if istable(actorData.class) then
				entity_class = 'entities/' .. actorData.class[1] .. '.png'
			elseif isstring(actorData.class) then
				entity_class = 'entities/' .. actorData.class .. '.png'
			end

			spawnmenu.CreateContentIcon('BackgroundNPCs', self.PropPanel, {
				nicename = actorData.name,
				spawnname = actorType,
				material = actorData.icon or entity_class
			})
		end
	end

	node.DoClick = function(self)
		self:DoPopulate()
		pnlContent:SwitchPanel(self.PropPanel)
	end
end)

spawnmenu.AddContentType('BackgroundNPCs', function(container, obj)
	obj.spawnname = obj.spawnname or 'None'
	obj.nicename = obj.nicename or 'None'
	obj.material = obj.material or ''
	obj.admin = obj.admin or false

	local icon = vgui.Create('ContentIcon', container)
	icon:SetContentType('BackgroundNPCs')
	icon:SetSpawnName(obj.spawnname)
	icon:SetName(obj.nicename)
	icon:SetMaterial(obj.material)
	icon:SetAdminOnly(obj.admin)
	icon:SetColor(Color(0, 0, 0, 255))

	icon.DoClick = function()
		if obj.admin and not LocalPlayer():IsAdmin() and not LocalPlayer():IsSuperAdmin() then
			return
		end

		snet.InvokeServer('BGN_ActorSpawnmenu', obj.spawnname)
		surface.PlaySound('ui/buttonclickrelease.wav')
	end

	icon.OpenMenu = function()
		local contextMenu = DermaMenu()

		contextMenu:AddOption('#spawnmenu.menu.copy', function()
			SetClipboardText(obj.spawnname)
		end):SetIcon('icon16/page_copy.png')

		contextMenu:AddOption('#spawnmenu.menu.spawn_with_toolgun', function()
			snet.InvokeServer('BGN_ActorSpawnmenuToolSpawner', obj.spawnname)

			local toolData = LocalPlayer():GetTool('bgn_actor_spawner')
			if toolData then
				toolData.actorType = obj.spawnname
			end
		end):SetIcon('icon16/brick_add.png')

		contextMenu:Open()
	end

	if IsValid(container) then
		container:Add(icon)
	end

	return icon
end)

hook.Add('PostSlibSpawnmenuAddContentType', 'BackgroundNPCs', function(name, icon)
	if not icon or name ~= 'npc' then return end

	local openMenuExtra = icon.OpenMenuExtra
	local npcClass = icon:GetSpawnName()

	icon.OpenMenuExtra = function(self, menu)
		openMenuExtra(self, menu)

		do
			local subMenu, swg = menu:AddSubMenu('Background NPCs - Spawn')
			swg:SetIcon('icon16/monkey.png')

			subMenu:AddOption('No actor', function()
				snet.InvokeServer('BGN_ActorSpawnmenuToolSpecificSpawner', npcClass)
			end):SetIcon('icon16/cross.png')

			subMenu:AddSpacer()

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				subMenu:AddOption('Spawn - ' .. (actorData.name or actorType), function()
					snet.InvokeServer('BGN_ActorSpawnmenuToolSpecificSpawner', npcClass, actorType)
				end):SetIcon('icon16/monkey.png')
			end
		end

		do
			local subMenu, swg = menu:AddSubMenu('Background NPCs - Spawn Reset')
			swg:SetIcon('icon16/cross.png')

			subMenu:AddOption('Everyone', function()
				snet.InvokeServer('BGN_ActorSpawnmenuResetSpawner', true)
			end):SetIcon('icon16/cross.png')

			subMenu:AddSpacer()

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				subMenu:AddOption('Reset spawn - ' .. (actorData.name or actorType), function()
					snet.InvokeServer('BGN_ActorSpawnmenuResetSpawner', actorType)
				end):SetIcon('icon16/monkey.png')
			end
		end
	end
end)

hook.Add('PopulateMenuBar', 'BackgroundNPCs_MenuBar', function(menubar)
	local m = menubar:AddOrGetMenu('Background NPCs')

	local actorsPanel = m:AddSubMenu('Spawner')
	actorsPanel:SetDeleteSelf(false)
	actorsPanel:AddCVar('Not spawn', 'bgn_spawnmenu_default_spawner', '')
	actorsPanel:AddSpacer()

	for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
		actorsPanel:AddCVar(actorData.name or actorType, 'bgn_spawnmenu_default_spawner', actorType)
	end
end)

cvars.AddChangeCallback('bgn_spawnmenu_default_spawner', function(_, _, actorType)
	snet.InvokeServer('BGN_ActorSpawnmenuToolDefaultSpawner', actorType)
end, 'bgn_spawnmenu_default_spawner')