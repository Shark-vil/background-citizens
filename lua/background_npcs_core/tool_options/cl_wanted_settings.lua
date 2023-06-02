local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_enable_wanted_mode',
		['Command'] = 'bgn_enable_wanted_mode',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_wanted_time',
		['Command'] = 'bgn_wanted_time',
		['Type'] = 'Float',
		['Min'] = '0',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_level',
		['Command'] = 'bgn_wanted_level',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_hud_text',
		['Command'] = 'bgn_wanted_hud_text',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_hud_stars',
		['Command'] = 'bgn_wanted_hud_stars',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_disable_halo',
		['Command'] = 'bgn_disable_halo',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_wanted_impunity_limit',
		['Command'] = 'bgn_wanted_impunity_limit',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_wanted_impunity_reduction_period',
		['Command'] = 'bgn_wanted_impunity_reduction_period',
		['Type'] = 'Float',
		['Min'] = '0',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_police_instantly',
		['Command'] = 'bgn_wanted_police_instantly',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_WantedSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Wanted_Settings',
		'#bgn.settings.wanted_title', '', '', TOOL_MENU)
end)