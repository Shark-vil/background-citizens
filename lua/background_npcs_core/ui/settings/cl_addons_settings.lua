local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.stormfox2',
		['Command'] = 'bgn_module_stormfox2',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.decent_vehicle',
		['Command'] = 'bgn_enable_dv_support',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.police_system',
		['Command'] = 'bgn_enable_police_system_support',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.bio_annihilation_two_replacement',
		['Command'] = 'bgn_module_bio_annihilation_two_replacement',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.arccw_weapon_replacement',
		['Command'] = 'bgn_module_arccw_weapon_replacement',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.arc9_weapon_replacement',
		['Command'] = 'bgn_module_arc9_weapon_replacement',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.tfa_weapon_replacement',
		['Command'] = 'bgn_module_tfa_weapon_replacement',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.followers_mod_addon',
		['Command'] = 'bgn_module_followers_mod_addon',
		['Help'] = true,
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.addon.n2money',
		['Command'] = 'bgn_module_n2money',
		['Help'] = true,
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_AddonsSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Addons_Settings', '#bgn.settings.addon', '', '', TOOL_MENU)
end)