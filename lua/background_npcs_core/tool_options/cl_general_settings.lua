local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.mod_enable',
		['Command'] = 'bgn_enable',
		['Help'] = true,
	})

	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.cl_citizens_load_route',
		['Command'] = 'cl_citizens_load_route ',
	})

	panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.cl_citizens_load_route.help'
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.peaceful_mode',
		['Command'] = 'bgn_peaceful_mode',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_friend_mode',
		['Command'] = 'bgn_friend_mode',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.bgn_agressive_mode',
		['Command'] = 'bgn_agressive_mode',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.ignore_another_npc',
		['Command'] = 'bgn_ignore_another_npc',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.chunk_system',
		['Command'] = 'bgn_chunk_system',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.general.chunk_size',
		['Command'] = 'bgn_chunk_size',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Max'] = '10000',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.general.debug',
		['Command'] = 'bgn_debug',
		['Help'] = true,
	})

	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.updateinfo',
		['Command'] = 'bgn_updateinfo',
	})

	panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.updateinfo.help'
	})

	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.reset_cvars_to_factory_settings',
		['Command'] = 'bgn_reset_cvars_to_factory_settings',
	})

	panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.reset_cvars_to_factory_settings.help'
	})

	panel:AddControl('Button', {
		['Label'] = '#bgn.settings.general.remove_routes',
		['Command'] = 'cl_citizens_remove_route yes',
	})

	panel:AddControl('Label', {
		['Text'] = '#bgn.settings.general.remove_routes.help'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_GeneralSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_General_Settings', '#bgn.settings.general', '', '', TOOL_MENU)
end)