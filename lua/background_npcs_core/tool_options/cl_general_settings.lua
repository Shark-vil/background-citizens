local function TOOL_MENU(Panel)
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_enable',
		['Command'] = 'bgn_enable',
		['Help'] = true,
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.cl_citizens_load_route',
		['Command'] = 'cl_citizens_load_route ',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.cl_citizens_load_route.help'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.peaceful_mode',
		['Command'] = 'bgn_peaceful_mode',
		['Help'] = true,
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_ignore_another_npc',
		['Command'] = 'bgn_ignore_another_npc',
		['Help'] = true,
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_debug',
		['Command'] = 'bgn_debug',
		['Help'] = true,
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.bgn_updateinfo',
		['Command'] = 'bgn_updateinfo',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_updateinfo.help'
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.bgn_reset_cvars_to_factory_settings',
		['Command'] = 'bgn_reset_cvars_to_factory_settings',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_reset_cvars_to_factory_settings.help'
	})

	Panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.bgn_remove_routes',
		['Command'] = 'cl_citizens_remove_route yes',
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.bgn_remove_routes.help'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_GeneralSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_General_Settings',
		'#bgn.settings.general_title', '', '', TOOL_MENU)
end)