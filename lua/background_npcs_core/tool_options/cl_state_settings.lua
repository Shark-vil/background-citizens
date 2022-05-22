local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_arrest_mode',
		['Command'] = 'bgn_arrest_mode',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_arrest_time',
		['Command'] = 'bgn_arrest_time',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '100',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_arrest_time_limit',
		['Command'] = 'bgn_arrest_time_limit',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '100',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_shot_sound_mode',
		['Command'] = 'bgn_shot_sound_mode',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_disable_dialogues',
		['Command'] = 'bgn_disable_dialogues',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_replics_enable',
		['Command'] = 'bgn_module_replics_enable',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_all_models_random',
		['Command'] = 'bgn_all_models_random',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_custom_gestures',
		['Command'] = 'bgn_module_custom_gestures',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_tactical_groups',
		['Command'] = 'bgn_module_tactical_groups',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_StateSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_States_Settings',
		'#bgn.settings.states_title', '', '', TOOL_MENU)
end)