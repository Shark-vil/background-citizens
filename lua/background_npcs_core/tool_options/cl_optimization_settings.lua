local function TOOL_MENU(Panel)
	Panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.optimization.bgn_disable_logic_radius',
		['Command'] = 'bgn_disable_logic_radius',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '1000'
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.optimization.bgn_disable_logic_radius.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_OptimizationSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Optimization_Settings',
		'#bgn.settings.optimization_title', '', '', TOOL_MENU)
end)