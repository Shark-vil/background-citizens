local function TOOL_MENU(panel)
	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.workshop.cl_citizens_compile_route',
		['Command'] = 'bgn_compile',
	})

	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.workshop.bgn_save_map',
		['Command'] = 'bgn_save_map',
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_WorkshopServices', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Workshop_Services',
		'#bgn.settings.workshop_title', '', '', TOOL_MENU)
end)