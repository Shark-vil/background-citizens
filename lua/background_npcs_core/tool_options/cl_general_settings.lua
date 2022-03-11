local function TOOL_MENU(Panel)
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_enable',
		['Command'] = 'bgn_enable'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_enable.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_ignore_another_npc',
		['Command'] = 'bgn_ignore_another_npc'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_ignore_another_npc.description'
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.cl_citizens_load_route',
		['Command'] = 'cl_citizens_load_route ',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.cl_citizens_load_route.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_debug',
		['Command'] = 'bgn_debug'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_debug.description'
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.bgn_updateinfo',
		['Command'] = 'bgn_updateinfo',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_updateinfo.description'
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.bgn_reset_cvars_to_factory_settings',
		['Command'] = 'bgn_reset_cvars_to_factory_settings',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_reset_cvars_to_factory_settings.description'
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.bgn_remove_routes',
		['Command'] = 'cl_citizens_remove_route yes',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_remove_routes.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_GeneralSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_General_Settings',
		'#bgn.settings.general_title', '', '', TOOL_MENU)
end)