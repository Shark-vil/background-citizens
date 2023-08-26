local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.drop_money',
		['Command'] = 'bgn_drop_money',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.shot_sound_mode',
		['Command'] = 'bgn_shot_sound_mode',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.disable_dialogues',
		['Command'] = 'bgn_disable_dialogues',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.replics_enable',
		['Command'] = 'bgn_module_replics_enable',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.all_models_random',
		['Command'] = 'bgn_all_models_random',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.custom_gestures',
		['Command'] = 'bgn_module_custom_gestures',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.extension.tactical_groups',
		['Command'] = 'bgn_module_tactical_groups',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_StateSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_States_Settings', '#bgn.settings.extension', '', '', TOOL_MENU)
end)