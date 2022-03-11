local function TOOL_MENU(Panel)
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_arrest_mode',
		['Command'] = 'bgn_arrest_mode'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_arrest_mode.description'
	})

	Panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_arrest_time',
		['Command'] = 'bgn_arrest_time',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '100'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_arrest_time.description'
	})

	Panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_arrest_time_limit',
		['Command'] = 'bgn_arrest_time_limit',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '100'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_arrest_time_limit.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_shot_sound_mode',
		['Command'] = 'bgn_shot_sound_mode'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_shot_sound_mode.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_enable_dv_support',
		['Command'] = 'bgn_enable_dv_support'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_enable_dv_support.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_enable_police_system_support',
		['Command'] = 'bgn_enable_police_system_support'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_enable_police_system_support.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_disable_dialogues',
		['Command'] = 'bgn_disable_dialogues'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_disable_dialogues.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_replics_enable',
		['Command'] = 'bgn_module_replics_enable'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_module_replics_enable.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_bio_annihilation_two_replacement',
		['Command'] = 'bgn_module_bio_annihilation_two_replacement'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_module_bio_annihilation_two_replacement.description'
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_arccw_weapon_replacement',
		['Command'] = 'bgn_module_arccw_weapon_replacement'
	}); Panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_module_arccw_weapon_replacement.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_StateSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_States_Settings',
		'#bgn.settings.states_title', '', '', TOOL_MENU)
end)