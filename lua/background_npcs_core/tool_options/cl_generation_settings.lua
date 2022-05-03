local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes',
		['Command'] = 'bgn_dynamic_nodes'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.spawn.bgn_dynamic_nodes.description'
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes_restict',
		['Command'] = 'bgn_enable_dynamic_nodes_only_when_mesh_not_exists'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.spawn.bgn_dynamic_nodes_restict.description'
	})

	panel:AddControl('ListBox', {
		['Label'] = '#bgn.settings.spawn.bgn_dynamic_nodes_type',
		['Command'] = 'bgn_dynamic_nodes_type',
		['Options'] = {
			['grid'] = { ['bgn_dynamic_nodes_type'] = 'grid' },
			['random'] = { ['bgn_dynamic_nodes_type'] = 'random' },
		}
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.spawn.bgn_dynamic_nodes_type.description'
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.spawn.bgn_runtime_generator_grid_offset',
		['Command'] = 'bgn_runtime_generator_grid_offset',
		['Type'] = 'Integer',
		['Min'] = '50',
		['Max'] = '500'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.spawn.bgn_runtime_generator_grid_offset.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_GenerationSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Generation_Settings',
		'#bgn.settings.generation_title', '', '', TOOL_MENU)
end)