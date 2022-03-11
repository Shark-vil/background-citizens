local function TOOL_MENU(Panel)
	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.workshop.cl_citizens_compile_route',
		['Command'] = 'bgn_compile',
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_WorkshopServices', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Workshop_Services',
		'#bgn.settings.workshop_title', '', '', TOOL_MENU)
end)