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
		Label = '#bgn.settings.states.bgn_arrest_mode',
		Command = 'bgn_arrest_mode' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_arrest_mode.description'
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

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.states.bgn_arrest_time",
		["Command"] = "bgn_arrest_time",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "100"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_arrest_time.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.states.bgn_arrest_time_limit",
		["Command"] = "bgn_arrest_time_limit",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "100"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_arrest_time_limit.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_shot_sound_mode',
		Command = 'bgn_shot_sound_mode' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_shot_sound_mode.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_disable_halo',
		Command = 'bgn_disable_halo' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_disable_halo.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_enable_dv_support',
		Command = 'bgn_enable_dv_support' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_enable_dv_support.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.states.bgn_disable_dialogues',
		Command = 'bgn_disable_dialogues' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.states.bgn_disable_dialogues.description'
	})
end

hook.Add("PopulateToolMenu", "BGN_TOOL_CreateMenu_StateSettings", function()
	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_States_Settings", 
		"#bgn.settings.states_title", "", "", TOOL_MENU)
end)