local en_lang = {}
local ru_lang = {}

en_lang['bgn.settings.general.bgn_enable'] = 'Enable background NPCs'
en_lang['bgn.settings.general.bgn_enable.description'] = 'Description: toggles the modification activity.'
en_lang['bgn.settings.general.bgn_max_npc'] = 'Maximum number of NPCs on the map'
en_lang['bgn.settings.general.bgn_max_npc.description'] = 'Description: the maximum number of background NPCs on the map.'
en_lang['bgn.settings.general.bgn_ignore_another_npc'] = 'Ignore another NPCs'
en_lang['bgn.settings.general.bgn_ignore_another_npc.description'] = 'Description: if this parameter is active, then NPCs will ignore any other spawned NPCs.'
en_lang['bgn.settings.general.cl_citizens_load_route'] = 'Load points'
en_lang['bgn.settings.general.cl_citizens_load_route.description'] = 'Description: loads the movement mesh for NPCs. You can use this if for some reason the mesh didn\'t load or you reset it.'
en_lang['bgn.settings.general.bgn_reset_cvars_to_factory_settings'] = 'Reset to factory settings'

ru_lang['bgn.settings.general.bgn_enable'] = 'Включить фоновых NPC'
ru_lang['bgn.settings.general.bgn_enable.description'] = 'Описание: переключает активность модификации.'
ru_lang['bgn.settings.general.bgn_max_npc'] = 'Максимальное количество NPC на карте'
ru_lang['bgn.settings.general.bgn_max_npc.description'] = 'Описание: максимальное количество фоновых NPC на карте.'
ru_lang['bgn.settings.general.bgn_ignore_another_npc'] = 'Игнорировать других NPC'
ru_lang['bgn.settings.general.bgn_ignore_another_npc.description'] = 'Описание: если этот параметр активен, то NPC будут игнорировать любых других созданных NPC.'
ru_lang['bgn.settings.general.cl_citizens_load_route'] = 'Загрузить точки'
ru_lang['bgn.settings.general.cl_citizens_load_route.description'] = 'Описание: загружает сетку передвижения для NPC. Вы можете использовать это, если по какой-то причине сетка не загрузилась или вы её сбросили.'
ru_lang['bgn.settings.general.bgn_reset_cvars_to_factory_settings'] = 'Сбросить до заводских настроек'

local function GeneralSettingsMenu(Panel)
	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.general.bgn_enable',
		Command = 'bgn_enable' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.general.bgn_enable.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.general.bgn_max_npc",
		["Command"] = "bgn_max_npc",
		["Type"] = "Integer",
		["Min"] = "0",
		["Max"] = "200"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.general.bgn_max_npc.description'
	})

	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.general.bgn_ignore_another_npc',
		Command = 'bgn_ignore_another_npc' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.general.bgn_ignore_another_npc.description'
	})

	Panel:AddControl("Button", {
		["Label"] = "#bgn.settings.general.cl_citizens_load_route",
		["Command"] = "cl_citizens_load_route ",
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.general.cl_citizens_load_route.description'
	})

	Panel:AddControl("Button", {
		["Label"] = "#bgn.settings.general.bgn_reset_cvars_to_factory_settings",
		["Command"] = "bgn_reset_cvars_to_factory_settings",
	})
end

en_lang['bgn.settings.client.bgn_cl_field_view_optimization'] = 'Enable field of view optimization'
en_lang['bgn.settings.client.bgn_cl_field_view_optimization.description'] = 'Description: this can increase your FPS with a lot of NPCs. Not recommended for use with other optimization mods.'
en_lang['bgn.settings.client.bgn_cl_field_view_optimization_range'] = 'Activation distance'
en_lang['bgn.settings.client.bgn_cl_field_view_optimization_range.description'] = 'Description: the distance after which the field of view check begins.'


ru_lang['bgn.settings.client.bgn_cl_field_view_optimization'] = 'Включить оптимизацию поля зрения'
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization.description'] = 'Описание: это может повысить ваш FPS при большом количестве НПС. Не рекомендуется использовать с другими модами на оптимизацию.'
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization_range'] = 'Дистанция активации'
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization_range.description'] = 'Описание: дистанция после которой начинает действовать проверка поля зрения.'

local function ClientSettingsMenu(Panel)
	Panel:AddControl('CheckBox', {
		Label = '#bgn.settings.client.bgn_cl_field_view_optimization',
		Command = 'bgn_cl_field_view_optimization' 
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.client.bgn_cl_field_view_optimization.description'
	})

	Panel:AddControl("Slider", {
		["Label"] = "#bgn.settings.client.bgn_cl_field_view_optimization_range",
		["Command"] = "bgn_cl_field_view_optimization_range",
		["Type"] = "Integer",
		["Min"] = "0",
		["Max"] = "2000"
	}); Panel:AddControl('Label', {
		Text = '#bgn.settings.client.bgn_cl_field_view_optimization_range.description'
	})
end

en_lang['bgn.settings.spawn.bgn_spawn_radius'] = 'NPC spawn radius'
en_lang['bgn.settings.spawn.bgn_spawn_radius.description'] = 'Description: NPC spawn radius relative to the player.'
en_lang['bgn.settings.spawn.bgn_spawn_radius_visibility'] = 'Radius of activation of the point visibility check'
en_lang['bgn.settings.spawn.bgn_spawn_radius_visibility.description'] = 'Description: triggers an NPC visibility check within this radius to avoid spawning entities in front of the player.'
en_lang['bgn.settings.spawn.bgn_spawn_radius_raytracing'] = 'Radius of activation of the point visibility check by raytracing'
en_lang['bgn.settings.spawn.bgn_spawn_radius_raytracing.description'] = 'Description: checks the spawn points of NPCs using ray tracing in a given radius. This parameter must not be more than - bgn_spawn_radius_visibility. 0 - Disable checker'
en_lang['bgn.settings.spawn.bgn_spawn_block_radius'] = 'NPC spawn blocking radius relative to each player'
en_lang['bgn.settings.spawn.bgn_spawn_block_radius.description'] = 'Description: prohibits spawning NPCs within a given radius. Must not be more than the parameter - bgn_spawn_radius_ray_tracing. 0 - Disable checker'
en_lang['bgn.settings.spawn.bgn_spawn_period'] = 'The period between spawning NPCs (Change requires restart)'
en_lang['bgn.settings.spawn.bgn_spawn_period.description'] = 'Description: sets the delay between spawning of each NPC.'

ru_lang['bgn.settings.spawn.bgn_spawn_radius'] = 'Радиус спавна НПС'
ru_lang['bgn.settings.spawn.bgn_spawn_radius.description'] = 'Описание: радиус появления NPC относительно игрока.'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_visibility'] = 'Радиус активации проверки видимости точки'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_visibility.description'] = 'Описание: запускает проверку видимости NPC в этом радиусе, чтобы избежать появления сущностей перед игроком.'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_raytracing'] = 'Радиус активации проверки видимости точки с использованием трассировки лучей'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_raytracing.description'] = 'Описание: проверяет точки появления NPC с помощью трассировки лучей в заданном радиусе. Этот параметр не должен быть больше - bgn_spawn_radius_visibility. 0 - отключить проверку'
ru_lang['bgn.settings.spawn.bgn_spawn_block_radius'] = 'Радиус блокировки появления NPC относительно каждого игрока'
ru_lang['bgn.settings.spawn.bgn_spawn_block_radius.description'] = 'Описание: запрещает спавн NPC в заданном радиусе. Не может быть больше параметра - bgn_spawn_radius_ray_tracing. 0 - отключить проверку'
ru_lang['bgn.settings.spawn.bgn_spawn_period'] = 'Период между появлением NPC (изменение требует перезапуска)'
ru_lang['bgn.settings.spawn.bgn_spawn_period.description'] = 'Описание: устанавливает задержку между спавном каждого НПС.'

local function SpawnSettingsMenu(Panel)
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

en_lang['bgn.settings.states.bgn_enable_wanted_mode'] = 'Enable wanted mode'
en_lang['bgn.settings.states.bgn_enable_wanted_mode.description'] = 'Description: enables or disables wanted mode.'
en_lang['bgn.settings.states.bgn_wanted_time'] = 'Wanted time'
en_lang['bgn.settings.states.bgn_wanted_time.description'] = 'Description: the time you need to go through to remove the wanted level.'
en_lang['bgn.settings.states.bgn_wanted_level'] = 'Wanted level'
en_lang['bgn.settings.states.bgn_wanted_level.description'] = 'Description: enable the function of increasing the wanted level depending on the number of murders.'
en_lang['bgn.settings.states.bgn_wanted_hud_text'] = 'Wanted time text'
en_lang['bgn.settings.states.bgn_wanted_hud_text.description'] = 'Description: display text about the remaining wanted time.'
en_lang['bgn.settings.states.bgn_wanted_hud_stars'] = 'Wanted stars'
en_lang['bgn.settings.states.bgn_wanted_hud_stars.description'] = 'Description: Display the wanted level as a star.'
en_lang['bgn.settings.states.bgn_arrest_mode'] = 'Enable arrest mode'
en_lang['bgn.settings.states.bgn_arrest_mode.description'] = 'Description: includes a player arrest module. Attention! It won\'t do anything in the sandbox. By default, there is only a DarkRP compatible hook. If you activate this module in an unsupported gamemode, then after the arrest the NPCs will exclude you from the list of targets.'
en_lang['bgn.settings.states.bgn_arrest_time'] = 'Arrest time'
en_lang['bgn.settings.states.bgn_arrest_time.description'] = 'Description: sets the time allotted for your detention.'
en_lang['bgn.settings.states.bgn_arrest_time_limit'] = 'Arrest time limit'
en_lang['bgn.settings.states.bgn_arrest_time_limit.description'] = 'Description: sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.'
en_lang['bgn.settings.states.bgn_shot_sound_mode'] = 'Enable reaction to shot sounds'
en_lang['bgn.settings.states.bgn_shot_sound_mode.description'] = 'Description: NPCs will react to the sound of a shot as if someone was shooting at an ally. (Warning: this function is experimental and not recommended for use)'

ru_lang['bgn.settings.states.bgn_enable_wanted_mode'] = 'Включить режим розыска'
ru_lang['bgn.settings.states.bgn_enable_wanted_mode.description'] = 'Описание: включает или отключает режим розыска.'
ru_lang['bgn.settings.states.bgn_wanted_time'] = 'Время розыска'
ru_lang['bgn.settings.states.bgn_wanted_time.description'] = 'Описание: время которое нужно переждать чтобы убрать уровень розыска.'
ru_lang['bgn.settings.states.bgn_wanted_level'] = 'Уровень розыска'
ru_lang['bgn.settings.states.bgn_wanted_level.description'] = 'Описание: включить функцию повышения уровня розыска в зависимости от количества убийств.'
ru_lang['bgn.settings.states.bgn_wanted_hud_text'] = 'Текст времени розыска'
ru_lang['bgn.settings.states.bgn_wanted_hud_text.description'] = 'Описание: отображать текст об оставшеся времени розыска.'
ru_lang['bgn.settings.states.bgn_wanted_hud_stars'] = 'Звёзды розыска'
ru_lang['bgn.settings.states.bgn_wanted_hud_stars.description'] = 'Описание: отображать уровень розыска в виде звёзды.'
ru_lang['bgn.settings.states.bgn_arrest_mode'] = 'Включить режим ареста'
ru_lang['bgn.settings.states.bgn_arrest_mode.description'] = 'Описание: включает модуль ареста игрока. Внимание! В песочнице он ничего не делает. По умолчанию есть крючок только для DarkRP. Если вы активируете этот модуль в неподдерживаемом игровом режиме, то после ареста NPC просто исключат вас из списка целей.'
ru_lang['bgn.settings.states.bgn_arrest_time'] = 'Время ареста'
ru_lang['bgn.settings.states.bgn_arrest_time.description'] = 'Описание: устанавливает время, отведенное на ваше задержание.'
ru_lang['bgn.settings.states.bgn_arrest_time_limit'] = 'Лимит времени на задержание'
ru_lang['bgn.settings.states.bgn_arrest_time_limit.description'] = 'Описание: устанавливает, как долго полиция будет игнорировать вас во время ареста. Если вы откажетесь повиноваться по истеччению времени, они начнут вас атаковать.'
ru_lang['bgn.settings.states.bgn_shot_sound_mode'] = 'Включить реакцию на звуки выстрела'
ru_lang['bgn.settings.states.bgn_shot_sound_mode.description'] = 'Описание: NPC будут реагировать на звуки выстрела, как если бы кто-то стрелял по союзнику. (Предупреждение: функция эксперементальная и не рекомендуется к использованию)'

local function StatesSettingsMenu(Panel)
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
end

en_lang['bgn.settings.active_npcs.description'] = 'Description: you can disable some NPCs if you don\'t want to spawn them anymore. ATTENTION! If you disable an NPC, it will not automatically change the fullness relative to other NPCs! If you want to customize the configuration in detail, download the addon sources and change the configuration file!'

ru_lang['bgn.settings.active_npcs.description'] = 'Описание: вы можете отключить некоторых NPC, если не хотите чтобы они спавнились. ВНИМАНИЕ! Если вы отключите NPC, то соотношение плотности относительно других NPC не поменяется! Если вы хотите детально настроить конфигурацию, скачайте исходники аддона и измените файл конфигурации!'

local function ActiveNPCsMenu(Panel)
	local exists_types = {}
	for npcType, v in pairs(bgNPC.cfg.npcs_template) do
		if not table.HasValue(exists_types, npcType) then
			Panel:AddControl('CheckBox', {
				Label = npcType,
				Command = 'bgn_npc_type_' .. npcType
			})
			table.insert(exists_types, npcType)
		end
	end

	Panel:AddControl('Label', {
		Text = '#bgn.settings.active_npcs.description'
	})
end

en_lang['bgn.settings.workshop.cl_citizens_compile_route'] = 'Compile point mesh for workshop'

ru_lang['bgn.settings.workshop.cl_citizens_compile_route'] = 'Скомпилировать сетку для мастерской'

local function WorkshopServicesMenu(Panel)
	Panel:AddControl("Button", {
		["Label"] = "#bgn.settings.workshop.cl_citizens_compile_route",
		["Command"] = "cl_citizens_compile_route",
	})
end

hook.Add("AddToolMenuCategories", "BGN_TOOL_CreateOptionsCategory", function()
	spawnmenu.AddToolCategory("Options", "Background NPCs", "#Background NPCs" )
end)

en_lang['bgn.settings.general_title'] = 'General Settings'
en_lang['bgn.settings.client_title'] = 'Client Settings'
en_lang['bgn.settings.spawn_title'] = 'Spawn Settings'
en_lang['bgn.settings.states_title'] = 'States Settings'
en_lang['bgn.settings.active_title'] = 'Active NPC Groups'
en_lang['bgn.settings.workshop_title'] = 'Workshop Services'

ru_lang['bgn.settings.general_title'] = 'Главные Настройки'
ru_lang['bgn.settings.client_title'] = 'Настройки клиента'
ru_lang['bgn.settings.spawn_title'] = 'Настройки Спавна'
ru_lang['bgn.settings.states_title'] = 'Настройки Состояний'
ru_lang['bgn.settings.active_title'] = 'Активные Группы NPC'
ru_lang['bgn.settings.workshop_title'] = 'Сервис Мастерской'

local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
for k, v in pairs(lang) do
	language.Add(k, v)
end

hook.Add("PopulateToolMenu", "BGN_TOOL_CreateSettingsMenu", function()
	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_General_Settings", 
		"#bgn.settings.general_title", "", "", GeneralSettingsMenu)

	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Client_Settings", 
		"#bgn.settings.client_title", "", "", ClientSettingsMenu)

	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Spawn_Settings", 
		"#bgn.settings.spawn_title", "", "", SpawnSettingsMenu)

	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_States_Settings", 
		"#bgn.settings.states_title", "", "", StatesSettingsMenu)

	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Active_NPC_Groups", 
		"#bgn.settings.active_title", "", "", ActiveNPCsMenu)

	spawnmenu.AddToolMenuOption("Options", "Background NPCs", "BGN_Workshop_Services", 
		"#bgn.settings.workshop_title", "", "", WorkshopServicesMenu)
end)