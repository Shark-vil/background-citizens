local ru_lang = {}
local en_lang = {}

--[[
  ______             _ _     _     
 |  ____|           | (_)   | |    
 | |__   _ __   __ _| |_ ___| |__  
 |  __| | '_ \ / _` | | / __| '_ \ 
 | |____| | | | (_| | | \__ \ | | |
 |______|_| |_|\__, |_|_|___/_| |_|
                __/ |              
               |___/               
--]]

--[[-----------------------------------------
   General settings menu
--]]
en_lang['bgn.settings.general.bgn_enable'] = 'Enable background NPCs'
en_lang['bgn.settings.general.bgn_enable.description'] = 'Description: toggles the modification activity.'
en_lang['bgn.settings.general.bgn_debug'] = 'Enable debug mode'
en_lang['bgn.settings.general.bgn_debug.description'] = 'Description: Turns on debug mode and prints additional information to the console.'
en_lang['bgn.settings.general.bgn_ignore_another_npc'] = 'Ignore another NPCs'
en_lang['bgn.settings.general.bgn_ignore_another_npc.description'] = 'Description: if this parameter is active, then NPCs will ignore any other spawned NPCs.'
en_lang['bgn.settings.general.cl_citizens_load_route'] = 'Load points'
en_lang['bgn.settings.general.cl_citizens_load_route.description'] = 'Description: loads the movement mesh for NPCs. You can use this if for some reason the mesh didn\'t load or you reset it.'
en_lang['bgn.settings.general.bgn_updateinfo'] = 'View release notes'
en_lang['bgn.settings.general.bgn_updateinfo.description'] = 'Description: open a page with information about the last update of the addon.'
en_lang['bgn.settings.general.bgn_reset_cvars_to_factory_settings'] = 'Reset to factory settings'
en_lang['bgn.settings.general.bgn_reset_cvars_to_factory_settings.description'] = 'Description: resets all settings in the options menu to default.'
en_lang['bgn.settings.general.bgn_remove_routes'] = 'Delete movement mesh file'
en_lang['bgn.settings.general.bgn_remove_routes.description'] = 'Description: removes the mesh file from the hard disk. You can use this if you want to update the movement mesh you downloaded from the workshop. After deleting, restart the map.'

--[[-----------------------------------------
   Client settings menu
--]]
en_lang['bgn.settings.client.bgn_cl_field_view_optimization'] = 'Enable field of view optimization'
en_lang['bgn.settings.client.bgn_cl_field_view_optimization.description'] = 'Description: this can increase your FPS with a lot of NPCs. Not recommended for use with other optimization mods.'
en_lang['bgn.settings.client.bgn_cl_field_view_optimization_range'] = 'Activation distance'
en_lang['bgn.settings.client.bgn_cl_field_view_optimization_range.description'] = 'Description: the distance after which the field of view check begins.'
en_lang['bgn.settings.general.bgn_cl_ambient_sound'] = 'Enable ambient sound'
en_lang['bgn.settings.general.bgn_cl_ambient_sound.description'] = 'Description: plays a crowd sound based on the number of actors around you.'

--[[-----------------------------------------
   Spawn settings menu
--]]
en_lang['bgn.settings.spawn.bgn_dynamic_nodes'] = 'Dynamic movement mesh'
en_lang['bgn.settings.spawn.bgn_dynamic_nodes.description'] = 'Description: allows you to generate a movement mesh automatically around the players. This is useful when the map does not have a movement mesh file. Keep in mind that this is a resource intensive process. It is recommended to create a movement mesh yourself, or generate one if the map has AI NavMesh.'
en_lang['bgn.settings.spawn.bgn_dynamic_nodes_restict'] = 'Dynamic movement mesh constraint'
en_lang['bgn.settings.spawn.bgn_dynamic_nodes_restict.description'] = 'Description: if enabled, the mesh will be generated only when there is no movement mesh file on the map. Otherwise, automatic generation will always be used.'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes_type'] = 'Tim dynamic mesh'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes_type.description'] = 'Description:\n' ..
'random - the mesh will be generated randomly. Increases variety, but accuracy is much lower. May not work at all in narrow spaces.\n' ..
'grid - the grid is generated in a staggered uniform pattern over the entire area around the player. Less random, but more likely to fill the area with move points. (Recommended)'
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
en_lang['bgn.settings.spawn.bgn_actors_teleporter'] = 'NPC teleportation (Experimental)'
en_lang['bgn.settings.spawn.bgn_actors_teleporter.description'] = 'Description: instead of removing the NPC after losing it from the players field of view, it will teleport to the nearest point. This will create the effect of a more populated city. Disable this option if you notice dropped frames.'
ru_lang['bgn.settings.spawn.bgn_actors_max_teleports'] = 'Maximum NPCs to teleport'
ru_lang['bgn.settings.spawn.bgn_actors_max_teleports.description'] = 'Description: how many NPCs can be teleported in one second. The larger the number, the more calculations will be performed. The teleport is calculated for each actor individually, without waiting for the teleport of another actor from his group.'

--[[-----------------------------------------
   State settings menu
--]]
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
en_lang['bgn.settings.states.bgn_arrest_mode.description'] = 'Description: includes a player arrest module.'
en_lang['bgn.settings.states.bgn_arrest_time'] = 'Arrest time'
en_lang['bgn.settings.states.bgn_arrest_time.description'] = 'Description: sets the time allotted for your detention.'
en_lang['bgn.settings.states.bgn_arrest_time_limit'] = 'Arrest time limit'
en_lang['bgn.settings.states.bgn_arrest_time_limit.description'] = 'Description: sets how long the police will ignore you during your arrest. If you refuse to obey after the lapse of time, they will start shooting at you.'
en_lang['bgn.settings.states.bgn_shot_sound_mode'] = 'Enable reaction to shot sounds'
en_lang['bgn.settings.states.bgn_shot_sound_mode.description'] = 'Description: NPCs will react to the sound of a shot as if someone was shooting at an ally. (Warning: this function is experimental and not recommended for use)'
en_lang['bgn.settings.states.bgn_disable_halo'] = 'Disable NPC highlighting stroke.'
en_lang['bgn.settings.states.bgn_disable_halo.description'] = 'Description: disables the effect of the outline of the NPC during the call and during the wanted.'
en_lang['bgn.settings.states.bgn_enable_dv_support'] = 'Enable "DV" addon support'
en_lang['bgn.settings.states.bgn_enable_dv_support.description'] = 'Description: includes compatibility with the "DV" addon and forces NPCs to use vehicles. Requires DV to have automatic loading of travel paths enabled!'
en_lang['bgn.settings.states.bgn_enable_police_system_support'] = 'Enable support for the addon "Police System"'
en_lang['bgn.settings.states.bgn_enable_police_system_support.description'] = 'Description: Enables compatibility with the "Police System" addon and overrides the default arrest method.'
en_lang['bgn.settings.states.bgn_disable_dialogues'] = 'Disable dialogues between NPCs'
en_lang['bgn.settings.states.bgn_disable_dialogues.description'] = 'Description: disables NPCs from communicating with each other.'
en_lang['bgn.settings.states.bgn_module_replics_enable'] = 'Enable text replics'
en_lang['bgn.settings.states.bgn_module_replics_enable.description'] = 'Description: enable text cues over the heads of NPCs.'
en_lang['bgn.settings.states.bgn_module_bio_annihilation_two_replacement'] = 'Enable support Bio-Annihilation II'
en_lang['bgn.settings.states.bgn_module_bio_annihilation_two_replacement.description'] = 'Description: enabled automatic replacement of zombies with NPCs from Bio-Annihilation II.'
en_lang['bgn.settings.states.bgn_module_arccw_weapon_replacement'] = 'Enable ArcCW support'
en_lang['bgn.settings.states.bgn_module_arccw_weapon_replacement.description'] = 'Description: enables automatic swapping for weapons from the ArcCW addon. Requires NPC weapon swapping to be enabled in ArcCW too!'

--[[-----------------------------------------
   Active npc group settings menu
--]]
en_lang['bgn.settings.active_npcs.description'] = 'Description: you can disable some NPCs if you don\'t want to spawn them anymore. ATTENTION! If you disable an NPC, it will not automatically change the fullness relative to other NPCs! If you want to customize the configuration in detail, download the addon sources and change the configuration file!'
en_lang['bgn.settings.active_npcs.bgn_disable_citizens_weapons'] = '> Disable weapon'
en_lang['bgn.settings.active_npcs.bgn_disable_citizens_weapons.description'] = 'Prohibits citizens from having weapons'
en_lang['bgn.settings.general.bgn_max_npc'] = 'Maximum number of NPCs on the map'
en_lang['bgn.settings.general.bgn_max_npc.description'] = 'Description: the maximum number of background NPCs on the map.'

--[[-----------------------------------------
   Workshop settings menu
--]]
en_lang['bgn.settings.workshop.cl_citizens_compile_route'] = 'Compile point mesh for workshop'

--[[-----------------------------------------
   Optimization settings menu
--]]
en_lang['bgn.settings.optimization.bgn_disable_logic_radius'] = 'Disable npc logic'
en_lang['bgn.settings.optimization.bgn_disable_logic_radius.description'] = 'Description: Disables the logic of NPCs beyond the specified radius, reducing the load on the game. 0 - disable setting'

--[[-----------------------------------------
   Options header menu
--]]
en_lang['bgn.settings.general_title'] = 'General'
en_lang['bgn.settings.client_title'] = 'Client'
en_lang['bgn.settings.spawn_title'] = 'Spawner'
en_lang['bgn.settings.states_title'] = 'Modules'
en_lang['bgn.settings.wanted_title'] = 'Wanted mode'
en_lang['bgn.settings.active_title'] = 'Actors'
en_lang['bgn.settings.workshop_title'] = 'Workshop'
en_lang['bgn.settings.optimization_title'] = 'Optimization'
en_lang['bgn.settings.unit_tests_title'] = 'Unit tests'

--[[
  _____               _             
 |  __ \             (_)            
 | |__) |   _ ___ ___ _  __ _ _ __  
 |  _  / | | / __/ __| |/ _` | '_ \ 
 | | \ \ |_| \__ \__ \ | (_| | | | |
 |_|  \_\__,_|___/___/_|\__,_|_| |_|
--]]

--[[-----------------------------------------
   General settings menu
--]]
ru_lang['bgn.settings.general.bgn_enable'] = 'Включить фоновых NPC'
ru_lang['bgn.settings.general.bgn_enable.description'] = 'Описание: переключает активность модификации.'
ru_lang['bgn.settings.general.bgn_debug'] = 'Включить режим отладки'
ru_lang['bgn.settings.general.bgn_debug.description'] = 'Описание: Включает режим отладки и выводит дополнительную информацию в консоль.'
ru_lang['bgn.settings.general.bgn_ignore_another_npc'] = 'Игнорировать других NPC'
ru_lang['bgn.settings.general.bgn_ignore_another_npc.description'] = 'Описание: если этот параметр активен, то NPC будут игнорировать любых других созданных NPC.'
ru_lang['bgn.settings.general.cl_citizens_load_route'] = 'Загрузить точки'
ru_lang['bgn.settings.general.cl_citizens_load_route.description'] = 'Описание: загружает сетку передвижения для NPC. Вы можете использовать это, если по какой-то причине сетка не загрузилась или вы её сбросили.'
ru_lang['bgn.settings.general.bgn_updateinfo'] = 'Посмотреть информацию о версии'
ru_lang['bgn.settings.general.bgn_updateinfo.description'] = 'Описание: откроет страницу с информацией о последнем обновлении аддона.'
ru_lang['bgn.settings.general.bgn_reset_cvars_to_factory_settings'] = 'Сбросить до заводских настроек'
ru_lang['bgn.settings.general.bgn_reset_cvars_to_factory_settings.description'] = 'Описание: сбрасывает все параметры настройки в меню опций до стандартных.'
ru_lang['bgn.settings.general.bgn_remove_routes'] = 'Удалить файл сетки перемещения'
ru_lang['bgn.settings.general.bgn_remove_routes.description'] = 'Описание: удаляет файл сетки перемещения с жёсткого диска. Вы можете использовать это, если хотите обновить сетку перемещения, скачанную из мастерской. После удаления следует перезапустить карту.'

--[[-----------------------------------------
   Client settings menu
--]]
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization'] = 'Включить оптимизацию поля зрения'
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization.description'] = 'Описание: это может повысить ваш FPS при большом количестве НПС. Не рекомендуется использовать с другими модами на оптимизацию.'
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization_range'] = 'Дистанция активации'
ru_lang['bgn.settings.client.bgn_cl_field_view_optimization_range.description'] = 'Описание: дистанция после которой начинает действовать проверка поля зрения.'
ru_lang['bgn.settings.general.bgn_cl_ambient_sound'] = 'Включить звук толпы'
ru_lang['bgn.settings.general.bgn_cl_ambient_sound.description'] = 'Описание: проигрывает звук толпы в зависимости от количества актёров вокруг вас.'

--[[-----------------------------------------
   Spawn settings menu
--]]
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes'] = 'Динамическая сетка передвижения'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes.description'] = 'Описание: позволяет генерировать сетку передвижения автоматически вокруг игроков. Это полезно, когда у карты нету файла сетки передвижения. Обратите внимание, что это ресурсозатратный процесс. Рекомендуется создать сетку передвижения самому, или сгенерировать, если на карте есть AI NavMesh.'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes_restict'] = 'Ограничение динамической сетки передвижения'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes_restict.description'] = 'Описание: если включено, то сетка будет генерироваться только тогда, когда на карте нету файла сетки передвижения. В противном случае всегда будет использоваться автоматическая генерация.'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes_type'] = 'Тим динамической сетки'
ru_lang['bgn.settings.spawn.bgn_dynamic_nodes_type.description'] = 'Описание:\n' ..
'random - сетка будет генерироваться рандомно. Повышает разнообразие, но точность значительно ниже. В узких коридорах может вообще не работать.\n' ..
'grid - сетка генерируется в шахматном равномерном порядке по всей площади вокруг игрока. Меньше рандома, но больше шансов заполнить область точками перемещения. (Рекомендуется)'
ru_lang['bgn.settings.spawn.bgn_spawn_radius'] = 'Радиус спавна НПС'
ru_lang['bgn.settings.spawn.bgn_spawn_radius.description'] = 'Описание: радиус появления NPC относительно игрока.'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_visibility'] = 'Радиус активации проверки видимости точки'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_visibility.description'] = 'Описание: запускает проверку видимости NPC в этом радиусе, чтобы избежать появления сущностей перед игроком.'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_raytracing'] = 'Радиус активации проверки видимости точки с использованием трассировки лучей'
ru_lang['bgn.settings.spawn.bgn_spawn_radius_raytracing.description'] = 'Описание: проверяет точки появления NPC с помощью трассировки лучей в заданном радиусе. Этот параметр не должен быть больше - bgn_spawn_radius_visibility. 0 - отключить проверку'
ru_lang['bgn.settings.spawn.bgn_spawn_block_radius'] = 'Радиус блокировки появления NPC относительно каждого игрока'
ru_lang['bgn.settings.spawn.bgn_spawn_block_radius.description'] = 'Описание: запрещает спавн NPC в заданном радиусе. Не может быть больше параметра - bgn_spawn_radius_ray_tracing. 0 - отключить проверку'
ru_lang['bgn.settings.spawn.bgn_spawn_period'] = 'Период между появлением NPC (изменение требует перезапуска)'
ru_lang['bgn.settings.spawn.bgn_spawn_period.description'] = 'Описание: устанавливает задержку между спавном каждого NPC.'
ru_lang['bgn.settings.spawn.bgn_actors_teleporter'] = 'Телепортация NPC (Эксперементально)'
ru_lang['bgn.settings.spawn.bgn_actors_teleporter.description'] = 'Описание: вместо удаления NPC после потери его из поля зрения игроков, он будет телепортироваться в ближайшую точку. Это создаст эффект более населённого города. Отключите эту опцию, если замечайте потерю кадров.'
ru_lang['bgn.settings.spawn.bgn_actors_max_teleports'] = 'Максимум NPC для телепортации'
ru_lang['bgn.settings.spawn.bgn_actors_max_teleports.description'] = 'Описание: сколько NPC можно телепортировать за одну секунду. Чем больше число - тем больше вычислений будет производится. Телепорт вычисляется для каждого актёра индивидуально, не дожидаясь телепорта другого актёра из своеё группы.'

--[[-----------------------------------------
   State settings menu
--]]
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
ru_lang['bgn.settings.states.bgn_arrest_mode.description'] = 'Описание: включает модуль ареста игрока.'
ru_lang['bgn.settings.states.bgn_arrest_time'] = 'Время ареста'
ru_lang['bgn.settings.states.bgn_arrest_time.description'] = 'Описание: устанавливает время, отведенное на ваше задержание.'
ru_lang['bgn.settings.states.bgn_arrest_time_limit'] = 'Лимит времени на задержание'
ru_lang['bgn.settings.states.bgn_arrest_time_limit.description'] = 'Описание: устанавливает, как долго полиция будет игнорировать вас во время ареста. Если вы откажетесь повиноваться по истеччению времени, они начнут вас атаковать.'
ru_lang['bgn.settings.states.bgn_shot_sound_mode'] = 'Включить реакцию на звуки выстрела'
ru_lang['bgn.settings.states.bgn_shot_sound_mode.description'] = 'Описание: NPC будут реагировать на звуки выстрела, как если бы кто-то стрелял по союзнику. (Предупреждение: функция эксперементальная и не рекомендуется к использованию)'
ru_lang['bgn.settings.states.bgn_disable_halo'] = 'Отключить выделение контура NPC'
ru_lang['bgn.settings.states.bgn_disable_halo.description'] = 'Описание: отключает эффект обводки NPC во время звонка и при розыске.'
ru_lang['bgn.settings.states.bgn_enable_dv_support'] = 'Включить поддержку аддона "DV"'
ru_lang['bgn.settings.states.bgn_enable_dv_support.description'] = 'Описание: включает совместимость с аддоном "DV" и ззаставляет NPC использовать автотранспорт. Требуется чтобы в DV была включена автоматическая загрузка путей передвижения!'
ru_lang['bgn.settings.states.bgn_enable_police_system_support'] = 'Включить поддержку аддона "Система Полиции"'
ru_lang['bgn.settings.states.bgn_enable_police_system_support.description'] = 'Описание: включает совместимость с аддоном "Система Полиции" и переопределяет стандартный метод ареста.'
ru_lang['bgn.settings.states.bgn_disable_dialogues'] = 'Отключить диалоги между NPC'
ru_lang['bgn.settings.states.bgn_disable_dialogues.description'] = 'Описание: отключает общение NPC друг с другом.'
ru_lang['bgn.settings.states.bgn_module_replics_enable'] = 'Включить текстовые реплики'
ru_lang['bgn.settings.states.bgn_module_replics_enable.description'] = 'Описание: включает текстовые реплики над головами NPC.'
ru_lang['bgn.settings.states.bgn_module_bio_annihilation_two_replacement'] = 'Включить поддержку Bio-Annihilation II'
ru_lang['bgn.settings.states.bgn_module_bio_annihilation_two_replacement.description'] = 'Описание: включает автоматическую замену зомби на NPC из Bio-Annihilation II.'
ru_lang['bgn.settings.states.bgn_module_arccw_weapon_replacement'] = 'Включить поддержку ArcCW'
ru_lang['bgn.settings.states.bgn_module_arccw_weapon_replacement.description'] = 'Описание: включает автоматическую замену на оружие из аддона ArcCW. Требуется чтобы в ArcCW тоже была включена замена оружия у NPC!'

--[[-----------------------------------------
   Active npc group settings menu
--]]
ru_lang['bgn.settings.active_npcs.description'] = 'Описание: вы можете отключить некоторых NPC, если не хотите чтобы они спавнились. ВНИМАНИЕ! Если вы отключите NPC, то соотношение плотности относительно других NPC не поменяется! Если вы хотите детально настроить конфигурацию, скачайте исходники аддона и измените файл конфигурации!'
ru_lang['bgn.settings.active_npcs.bgn_disable_citizens_weapons'] = '> Отключить оружие'
ru_lang['bgn.settings.active_npcs.bgn_disable_citizens_weapons.description'] = 'Запрещает гражданам иметь оружие'
ru_lang['bgn.settings.general.bgn_max_npc'] = 'Максимальное количество NPC на карте'
ru_lang['bgn.settings.general.bgn_max_npc.description'] = 'Описание: максимальное количество фоновых NPC на карте.'

--[[-----------------------------------------
   Workshop settings menu
--]]
ru_lang['bgn.settings.workshop.cl_citizens_compile_route'] = 'Скомпилировать сетку для мастерской'

--[[-----------------------------------------
   Optimization settings menu
--]]
ru_lang['bgn.settings.optimization.bgn_disable_logic_radius'] = 'Отключить логику NPC'
ru_lang['bgn.settings.optimization.bgn_disable_logic_radius.description'] = 'Описание: отключает логику НПС дальше заданного радиуса, уменьшая нагрузку на игру. 0 - отключить настройку'

--[[-----------------------------------------
   Options header menu
--]]
ru_lang['bgn.settings.general_title'] = 'Общее'
ru_lang['bgn.settings.client_title'] = 'Клиент'
ru_lang['bgn.settings.spawn_title'] = 'Спавнер'
ru_lang['bgn.settings.states_title'] = 'Модули'
ru_lang['bgn.settings.wanted_title'] = 'Режим розыска'
ru_lang['bgn.settings.active_title'] = 'Актёры'
ru_lang['bgn.settings.workshop_title'] = 'Мастерская'
ru_lang['bgn.settings.optimization_title'] = 'Оптимизация'
ru_lang['bgn.settings.unit_tests_title'] = 'Юнит тесты'

---------------------------------------------
---------- SET LANGUAGE FOR SYSTEM ----------
---------------------------------------------
local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
for k, v in pairs(lang) do
	language.Add(k, v)
end