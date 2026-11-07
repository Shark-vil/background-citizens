local function TOOL_MENU(panel)
	panel:AddControl('Header', {
		['Description'] = '==[ General ]==',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.enable_wanted_mode',
		['Command'] = 'bgn_enable_wanted_mode',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.level',
		['Command'] = 'bgn_wanted_level',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.police_instantly',
		['Command'] = 'bgn_wanted_police_instantly',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.wanted.time',
		['Command'] = 'bgn_wanted_time',
		['Type'] = 'Float',
		['Min'] = '0',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.wanted.impunity_limit',
		['Command'] = 'bgn_wanted_impunity_limit',
		['Type'] = 'Integer',
		['Min'] = '0',
		['Help'] = true,
	})

	panel:AddControl('Slider', {
		['Label'] = '#bgn.settings.wanted.impunity_reduction_period',
		['Command'] = 'bgn_wanted_impunity_reduction_period',
		['Type'] = 'Float',
		['Min'] = '0',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '==[ HUD ]==',
	})

	panel:AddControl('Header', {
		['Description'] = '=[ Client ]=',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.cl_disable_hud_local',
		['Command'] = 'bgn_cl_disable_hud_local',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '=[ Server ]=',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.hud_text',
		['Command'] = 'bgn_wanted_hud_text',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.hud_stars',
		['Command'] = 'bgn_wanted_hud_stars',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '==[ Halo ]==',
	})

	panel:AddControl('Header', {
		['Description'] = '=[ Client ]=',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.cl_disable_halo',
		['Command'] = 'bgn_cl_disable_halo',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.cl_disable_self_halo_wanted',
		['Command'] = 'bgn_cl_disable_self_halo_wanted',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '=[ Server ]=',
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.disable_halo_calling',
		['Command'] = 'bgn_disable_halo_calling',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.wanted.disable_halo_wanted',
		['Command'] = 'bgn_disable_halo_wanted',
		['Help'] = true,
	})

	panel:AddControl('Header', {
		['Description'] = '==[ Colors ]==',
	})

	panel:AddControl('Color', {
		['Label'] = '#bgn.settings.wanted.calling_police_text_color',
		['red'] = 'bgn_wanted_color_calling_police_text_r',
		['green'] = 'bgn_wanted_color_calling_police_text_g',
		['blue'] = 'bgn_wanted_color_calling_police_text_b',
		['Help'] = true,
	})

	panel:AddControl('Color', {
		['Label'] = '#bgn.settings.wanted.calling_police_halo_color',
		['red'] = 'bgn_wanted_color_calling_police_halo_r',
		['green'] = 'bgn_wanted_color_calling_police_halo_g',
		['blue'] = 'bgn_wanted_color_calling_police_halo_b',
		['Help'] = true,
	})

	panel:AddControl('Color', {
		['Label'] = '#bgn.settings.wanted.wanted_halo_color',
		['red'] = 'bgn_wanted_color_wanted_halo_r',
		['green'] = 'bgn_wanted_color_wanted_halo_g',
		['blue'] = 'bgn_wanted_color_wanted_halo_b',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_WantedSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Wanted_Settings', '#bgn.settings.wanted', '', '', TOOL_MENU)
end)