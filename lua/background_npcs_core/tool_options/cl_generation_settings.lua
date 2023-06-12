local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes',
		['Command'] = 'bgn_dynamic_nodes',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes_restict',
		['Command'] = 'bgn_enable_dynamic_nodes_only_when_mesh_not_exists',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes_save_progress',
		['Command'] = 'bgn_dynamic_nodes_save_progress',
		['Help'] = true,
	})

	panel:AddControl('ListBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes_type',
		['Command'] = 'bgn_dynamic_nodes_type',
		['Options'] = {
			['grid'] = { ['bgn_dynamic_nodes_type'] = 'grid' },
			['random'] = { ['bgn_dynamic_nodes_type'] = 'random' },
		}
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.spawn.bgn_dynamic_nodes_type.help'
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.bgn_runtime_generator_grid_offset',
		['Command'] = 'bgn_runtime_generator_grid_offset',
		['Type'] = 'Integer',
		['Min'] = '50',
		['Max'] = '500',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_GenerationSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Generation_Settings',
		'#bgn.settings.generation_title', '', '', TOOL_MENU)
end)