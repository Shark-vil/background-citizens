local function TOOL_MENU(Panel)
	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_enable_wanted_mode',
		Command = 'bgn_enable_wanted_mode' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_enable_wanted_mode.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.states.bgn_wanted_time",
		["Command"] = "bgn_wanted_time",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "1000"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_wanted_time.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_wanted_level',
		Command = 'bgn_wanted_level' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_wanted_level.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_wanted_hud_text',
		Command = 'bgn_wanted_hud_text' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_wanted_hud_text.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_wanted_hud_stars',
		Command = 'bgn_wanted_hud_stars' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_wanted_hud_stars.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_disable_halo',
		Command = 'bgn_disable_halo' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_disable_halo.description'
	})
end

hook.Add("PopulateToolMenu", "BGN_TOOL_CreateMenu_WantedSettings", function()
	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Wanted_Settings", 
		"#bgn.settings.wanted_title", "", "", TOOL_MENU)
end)