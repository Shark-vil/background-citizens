local function TOOL_MENU(panel)
	panel:AddControl('Header', {
		['Description'] = '==[ Client ]==',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.optimization.cl_field_view_optimization',
		['Command'] = 'bgn_cl_field_view_optimization',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.optimization.cl_field_view_optimization_range',
		['Command'] = 'bgn_cl_field_view_optimization_range',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Max'] = '2000',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '==[ Server ]==',
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.optimization.disable_logic',
		['Command'] = 'bgn_disable_logic_radius',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '1000',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.actors_teleporter',
		['Command'] = 'bgn_actors_teleporter',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.actors_max_teleports',
		['Command'] = 'bgn_actors_max_teleports',
		['Type'] = 'Integer',
		['Min'] = '1',
		['Max'] = '10',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_OptimizationSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Optimization_Settings', '#bgn.settings.optimization', '', '', TOOL_MENU)
end)