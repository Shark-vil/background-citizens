local function GeneralSettingsMenu(Panel)
	Panel:AddControl('CheckBox', {
        Label = 'Enable background NPCs',
        Command = 'bgn_enable' 
    }); Panel:AddControl('Label', {
        Text = 'Description: Toggles the modification activity. 1 - enabled, 0 - disabled.'
    })

	Panel:AddControl("Slider", {
        ["Label"] = "Maximum number of NPCs on the map",
        ["Command"] = "bgn_max_npc",
        ["Type"] = "Integer",
        ["Min"] = "0",
        ["Max"] = "200"
    }); Panel:AddControl('Label', {
        Text = 'Description: The maximum number of background NPCs on the map.'
    })

    Panel:AddControl('CheckBox', {
        Label = 'Ignore another NPCs',
        Command = 'bgn_ignore_another_npc' 
    }); Panel:AddControl('Label', {
        Text = 'Description: If this parameter is active, then NPCs will ignore any other spawned NPCs.'
    })

    Panel:AddControl("Button", {
        ["Label"] = "Load points",
        ["Command"] = "cl_citizens_load_route ",
    })

    Panel:AddControl('Label', {
        Text = '________________'
    })

    Panel:AddControl("Button", {
        ["Label"] = "Reset to factory settings",
        ["Command"] = "bgn_reset_cvars_to_factory_settings",
    })
end

local function SpawnSettingsMenu(Panel)
    Panel:AddControl("Slider", {
        ["Label"] = "NPC spawn radius",
        ["Command"] = "bgn_spawn_radius",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "5000"
    }); Panel:AddControl('Label', {
        Text = 'Description: NPC spawn radius relative to the player.'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "Radius of activation of the point visibility check",
        ["Command"] = "bgn_spawn_radius_visibility",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "5000"
    }); Panel:AddControl('Label', {
        Text = 'Description: Triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "Radius of activation of the point visibility check by raytracing",
        ["Command"] = "bgn_spawn_radius_raytracing",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "5000"
    }); Panel:AddControl('Label', {
        Text = 'Description: Checks the spawn points of NPCs using ray tracing in a given radius. This parameter must not be more than - bgn_spawn_radius_visibility. 0 - Disable checker'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "NPC spawn blocking radius relative to each player",
        ["Command"] = "bgn_spawn_block_radius",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "5000"
    }); Panel:AddControl('Label', {
        Text = 'Description: Prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "The period between spawning NPCs (Change requires restart)",
        ["Command"] = "bgn_spawn_period",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "50"
    }); Panel:AddControl('Label', {
        Text = 'Description: The period between the spawn of the NPC. Changes require a server restart.'
    })
end

local function StatesSettingsMenu(Panel)
    Panel:AddControl('CheckBox', {
        Label = 'Enable wanted mode',
        Command = 'bgn_enable_wanted_mode' 
    }); Panel:AddControl('Label', {
        Text = 'Description: Enables or disables wanted mode.'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "Wanted time",
        ["Command"] = "bgn_wanted_time",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "1000"
    }); Panel:AddControl('Label', {
        Text = 'Description: The time you need to go through to remove the wanted level.'
    })

    Panel:AddControl('CheckBox', {
        Label = 'Enable arrest mode',
        Command = 'bgn_arrest_mode' 
    }); Panel:AddControl('Label', {
        Text = 'Description: Includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "Arrest time",
        ["Command"] = "bgn_arrest_time",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "100"
    }); Panel:AddControl('Label', {
        Text = 'Description: Sets the time allotted for your detention.'
    })

    Panel:AddControl("Slider", {
        ["Label"] = "Arrest time limit",
        ["Command"] = "bgn_arrest_time_limit",
        ["Type"] = "Float",
        ["Min"] = "0",
        ["Max"] = "100"
    }); Panel:AddControl('Label', {
        Text = 'Description: Sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.'
    })
end

local function ActiveNPCsMenu(Panel)
    local exists_types = {}
    for k, v in ipairs(bgNPC.npc_classes) do
        if not table.HasValue(exists_types, v.type) then
            Panel:AddControl('CheckBox', {
                Label = v.type,
                Command = 'bgn_npc_type_' .. v.type
            })
            table.insert(exists_types, v.type)
        end
    end

    Panel:AddControl('Label', {
        Text = 'Description: You can disable some NPCs if you don\'t want to spawn them anymore. ATTENTION! If you disable an NPC, it will not automatically change the fullness relative to other NPCs! If you want to customize the configuration in detail, download the addon sources and change the configuration file!'
    })
end

local function WorkshopServicesMenu(Panel)
    Panel:AddControl("Button", {
        ["Label"] = "Compile point mesh for workshop",
        ["Command"] = "cl_citizens_compile_route",
    })
end

hook.Add("AddToolMenuCategories", "BGN_TOOL_CreateOptionsCategory", function()
	spawnmenu.AddToolCategory("Options", "Background NPCs", "#Background NPCs" )
end)

hook.Add("PopulateToolMenu", "BGN_TOOL_CreateSettingsMenu", function()
    spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_General_Settings", 
        "#BGN General Settings", "", "", GeneralSettingsMenu)

    spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Spawn_Settings", 
        "#BGN Spawn Settings", "", "", SpawnSettingsMenu)

    spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_States_Settings", 
        "#BGN States Settings", "", "", StatesSettingsMenu)

    spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Active_NPC_Groups", 
        "#BGN Active NPC Groups", "", "", ActiveNPCsMenu)

    spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Workshop_Services", 
        "#BGN Workshop Services", "", "", WorkshopServicesMenu)
end)