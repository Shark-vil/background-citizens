local function TOOL_MENU(panel)
	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.workshop.save_to_script',
		['Command'] = 'bgn_compile',
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_WorkshopServices', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Workshop_Services', '#bgn.settings.workshop', '', '', TOOL_MENU)
end)