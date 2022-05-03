local function TOOL_MENU(Panel)
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_enable_wanted_mode',
		['Command'] = 'bgn_enable_wanted_mode',
		['Help'] = true,
	})

	Panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.states.bgn_wanted_time',
		['Command'] = 'bgn_wanted_time',
		['Type'] = 'Float',
		['Min'] = '0',
		['Max'] = '1000',
		['Help'] = true,
	})
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_level',
		['Command'] = 'bgn_wanted_level',
		['Help'] = true,
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_hud_text',
		['Command'] = 'bgn_wanted_hud_text',
		['Help'] = true,
	})

	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_wanted_hud_stars',
		['Command'] = 'bgn_wanted_hud_stars',
		['Help'] = true,
	})
	Panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_disable_halo',
		['Command'] = 'bgn_disable_halo',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_WantedSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Wanted_Settings',
		'#bgn.settings.wanted_title', '', '', TOOL_MENU)
end)