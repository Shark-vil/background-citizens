-- spawnmenu.AddCreationTab('Background NPCs', function()
-- 	local ctrl = vgui.Create('SpawnmenuContentPanel')
-- 	ctrl:CallPopulateHook('InitSpawnmenuBGN')
-- 	return ctrl
-- end, 'icon16/user_suit.png', 50)

CreateClientConVar('bgn_spawnmenu_default_spawner', '', false)

local lang = slib.language({
	['default'] = {
		['sm_modname'] = 'Background NPCs',

		['sm_spawn_title'] = 'Background NPCs - Spawner',
		['sm_spawn_stop'] = 'Don\'t spawn',
		['sm_spawn_selector'] = 'Spawn NPC as',

		['sm_reset_title'] = 'Background NPCs - Reset spawn',
		['sm_reset_everyone'] = 'Reset spawn of all NPCs in the game',
		['sm_reset_selector'] = 'Stop NPC spawning as',

		['sm_main_spawner_title'] = 'Spawn NPC as an actor',
		['sm_main_override'] = 'Do not override NPC spawn',
	},
	['russian'] = {
		['sm_modname'] = 'Фоновые NPC',

		['sm_spawn_title'] = 'Фоновые NPC - Спавнер',
		['sm_spawn_stop'] = 'Не спавнить',
		['sm_spawn_selector'] = 'Спавнить NPC как',

		['sm_reset_title'] = 'Background NPCs - Сброс спавна',
		['sm_reset_everyone'] = 'Сбросить спавн всех NPC в игре',
		['sm_reset_selector'] = 'Прекратить спавн NPC как',

		['sm_main_spawner_title'] = 'Спавн NPC в качестве актёра',
		['sm_main_override'] = 'Не переопределять спавн NPC',
	}
})

hook.Add('PopulateNPCs', 'BackgroundNPCs', function(pnlContent, tree)
	local node = tree:AddNode(lang['sm_modname'], 'icon16/monkey.png')

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
	icon:SetContentType(lang['sm_modname'])
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

hook.Add('slib.PostSpawnmenuAddContentType', 'BackgroundNPCs', function(name, icon)
	if not icon or name ~= 'npc' then return end

	local BASE = icon.OpenMenuExtra
	local npcClass = icon:GetSpawnName()

	icon.OpenMenuExtra = function(self, menu)
		BASE(self, menu)

		do
			local sub_menu, panel = menu:AddSubMenu(lang['sm_spawn_title'])
			panel:SetIcon('icon16/monkey.png')

			sub_menu:AddOption(lang['sm_spawn_stop'], function()
				snet.InvokeServer('BGN_ActorSpawnmenuToolSpecificSpawner', npcClass)
			end):SetIcon('icon16/cross.png')

			sub_menu:AddSpacer()

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				sub_menu:AddOption(lang['sm_spawn_selector'] .. ' - ' .. (actorData.name or actorType), function()
					snet.InvokeServer('BGN_ActorSpawnmenuToolSpecificSpawner', npcClass, actorType)
				end):SetIcon('icon16/monkey.png')
			end
		end

		do
			local sub_menu, panel = menu:AddSubMenu(lang['sm_reset_title'])
			panel:SetIcon('icon16/cross.png')

			sub_menu:AddOption(lang['sm_reset_everyone'], function()
				snet.InvokeServer('BGN_ActorSpawnmenuResetSpawner', true)
			end):SetIcon('icon16/cross.png')

			sub_menu:AddSpacer()

			for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
				sub_menu:AddOption(lang['sm_reset_selector'] .. ' - ' .. (actorData.name or actorType), function()
					snet.InvokeServer('BGN_ActorSpawnmenuResetSpawner', actorType)
				end):SetIcon('icon16/monkey.png')
			end
		end
	end
end)

hook.Add('PopulateMenuBar', 'BackgroundNPCs_MenuBar', function(menubar)
	local m = menubar:AddOrGetMenu(lang['sm_modname'])

	local actorsPanel = m:AddSubMenu(lang['sm_main_spawner_title'])
	actorsPanel:SetDeleteSelf(false)
	actorsPanel:AddCVar(lang['sm_main_override'], 'bgn_spawnmenu_default_spawner', '')
	actorsPanel:AddSpacer()

	for actorType, actorData in SortedPairs(bgNPC.cfg.actors) do
		actorsPanel:AddCVar(actorData.name or actorType, 'bgn_spawnmenu_default_spawner', actorType)
	end
end)

cvars.AddChangeCallback('bgn_spawnmenu_default_spawner', function(_, _, actorType)
	snet.InvokeServer('BGN_ActorSpawnmenuToolDefaultSpawner', actorType)
end, 'bgn_spawnmenu_default_spawner')