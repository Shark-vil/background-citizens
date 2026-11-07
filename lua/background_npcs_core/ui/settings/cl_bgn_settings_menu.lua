-- Spawn menu -> Options -> Background NPCs: one button that opens the settings window (ui/menu/cl_menu.lua).
hook.Add('AddToolMenuTabs', 'BGN_TOOL_CreateOptionsCategory', function()
	spawnmenu.AddToolTab('Options', '#Options')
end)

hook.Add('AddToolMenuCategories', 'BGN_TOOL_CreateOptionsCategory', function()
	spawnmenu.AddToolCategory('Options', 'Background NPCs', '#bgn.menu.title')
end)

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_Settings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Settings', '#bgn.menu.settings', '', '', function(panel)
		panel:ClearControls()
		panel:Button('#bgn.menu.open', 'bgn_menu')
		panel:Help('#bgn.menu.open.help')
	end)
end)
