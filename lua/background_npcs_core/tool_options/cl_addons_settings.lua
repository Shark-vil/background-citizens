local function TOOL_MENU(panel)
	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_stormfox2',
		['Command'] = 'bgn_module_stormfox2'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_module_stormfox2.description'
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_enable_dv_support',
		['Command'] = 'bgn_enable_dv_support'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_enable_dv_support.description'
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_enable_police_system_support',
		['Command'] = 'bgn_enable_police_system_support'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_enable_police_system_support.description'
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_bio_annihilation_two_replacement',
		['Command'] = 'bgn_module_bio_annihilation_two_replacement'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_module_bio_annihilation_two_replacement.description'
	})

	panel:AddControl('CheckBox', {
		['Label'] = '#bgn.settings.states.bgn_module_arccw_weapon_replacement',
		['Command'] = 'bgn_module_arccw_weapon_replacement'
	}); panel:AddControl('Label', {
		['Text'] = '#bgn.settings.states.bgn_module_arccw_weapon_replacement.description'
	})
end

hook.Add('PopulateToolMenu', 'BGN_TOOL_CreateMenu_AddonsSettings', function()
	spawnmenu.AddToolMenuOption('Options', 'Background NPCs', 'BGN_Addons_Settings',
		'#bgn.settings.addons_title', '', '', TOOL_MENU)
end)