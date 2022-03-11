local function TOOL_MENU(panel)
	panel:AddControl('Header', {
		['Description'] = '==[ Client ]==',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.client.bgn_cl_field_view_optimization',
		['Command'] = 'bgn_cl_field_view_optimization'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.client.bgn_cl_field_view_optimization.description'
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.client.bgn_cl_field_view_optimization_range',
		['Command'] = 'bgn_cl_field_view_optimization_range',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Max'] = '2000'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.client.bgn_cl_field_view_optimization_range.description'
	})

	panel:AddControl('Header', {
		['Description'] = '==[ Server ]==',
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.optimization.bgn_disable_logic_radius',
		['Command'] = 'bgn_disable_logic_radius',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '1000'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.optimization.bgn_disable_logic_radius.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_OptimizationSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Optimization_Settings',
		'#bgn.settings.optimization_title', '', '', TOOL_MENU)
end)