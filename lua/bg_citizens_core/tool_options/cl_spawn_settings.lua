local function TOOL_MENU(Panel)
	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.spawn.bgn_spawn_radius",
		["Command"] = "bgn_spawn_radius",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "5000"
	}); Panel:AddControl('Label', {
		Text = '##bgn.settings.spawn.bgn_spawn_radius.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.spawn.bgn_spawn_radius_visibility",
		["Command"] = "bgn_spawn_radius_visibility",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "5000"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.spawn.bgn_spawn_radius_visibility.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.spawn.bgn_spawn_radius_raytracing",
		["Command"] = "bgn_spawn_radius_raytracing",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "5000"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.spawn.bgn_spawn_radius_raytracing.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.spawn.bgn_spawn_block_radius",
		["Command"] = "bgn_spawn_block_radius",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "5000"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.spawn.bgn_spawn_block_radius.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.spawn.bgn_spawn_period",
		["Command"] = "bgn_spawn_period",
		["Type"] = "Float",
		["Min"] = "0",
		["Max"] = "50"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.spawn.bgn_spawn_period.description'
	})
end

hook.Add("PopulateToolMenu", "BGN_TOOL_CreateMenu_SpawnSettings", function()
	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Spawn_Settings", 
		"#bgn.settings.spawn_title", "", "", TOOL_MENU)
end)