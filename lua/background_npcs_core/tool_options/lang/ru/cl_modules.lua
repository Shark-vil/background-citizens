--[[-----------------------------------------
	 State settings menu
--]]
return {
	['bgn.settings.states.bgn_enable_wanted_mode'] = 'Включить режим розыска',
	['bgn.settings.states.bgn_enable_wanted_mode.help'] = 'Включает или отключает режим розыска.',

	['bgn.settings.states.bgn_wanted_time'] = 'Время розыска',
	['bgn.settings.states.bgn_wanted_time.help'] = 'Время которое нужно переждать чтобы убрать уровень розыска.',

	['bgn.settings.states.bgn_wanted_level'] = 'Уровень розыска',
	['bgn.settings.states.bgn_wanted_level.help'] = 'Включить функцию повышения уровня розыска в зависимости от количества убийств.',

	['bgn.settings.states.bgn_wanted_hud_text'] = 'Текст времени розыска',
	['bgn.settings.states.bgn_wanted_hud_text.help'] = 'Отображать текст об оставшеся времени розыска.',

	['bgn.settings.states.bgn_wanted_hud_stars'] = 'Звёзды розыска',
	['bgn.settings.states.bgn_wanted_hud_stars.help'] = 'Отображать уровень розыска в виде звёзды.',

	['bgn.settings.states.bgn_wanted_calling_police_text_color'] = 'Цвет текста вызова полиции',
	['bgn.settings.states.bgn_wanted_calling_police_text_color.help'] = 'Задаёт цвет текста над актёром, который звонит в полицию.',

	['bgn.settings.states.bgn_wanted_calling_police_halo_color'] = 'Цвет обводки вызывающего полицию',
	['bgn.settings.states.bgn_wanted_calling_police_halo_color.help'] = 'Задаёт цвет обводки (halo) актёра, вызывающего полицию.',

	['bgn.settings.states.bgn_wanted_wanted_halo_color'] = 'Цвет обводки разыскиваемого',
	['bgn.settings.states.bgn_wanted_wanted_halo_color.help'] = 'Задаёт цвет обводки (halo) сущности, находящейся в розыске.',

	['bgn.settings.states.bgn_wanted_impunity_limit'] = 'Лимит безнаказанности',
	['bgn.settings.states.bgn_wanted_impunity_limit.help'] = 'Устанавливает количество убийств, при достижении которого вы гарантированно получите уровень розыска. Значение "0" отключает опцию.',

	['bgn.settings.states.bgn_wanted_impunity_reduction_period'] = 'Период снижения штрафа безнаказанности',
	['bgn.settings.states.bgn_wanted_impunity_reduction_period.help'] = 'Устанавливает период времени в секундах, через которое лимит крайних убийств игроков уменьшается на 1 число. Значение "0" отключает опцию.',

	['bgn.settings.states.bgn_wanted_police_instantly'] = 'Моментальный розыск за убийство полиции',
	['bgn.settings.states.bgn_wanted_police_instantly.help'] = 'Если эта функция включена, то при убийстве актёров из команды "Полиция" вы мгновенно получаете уровень розыска.',

	['bgn.settings.states.bgn_arrest_mode'] = 'Включить режим ареста',
	['bgn.settings.states.bgn_arrest_mode.help'] = 'Включает модуль ареста игрока.',

	['bgn.settings.states.bgn_arrest_time'] = 'Время ареста',
	['bgn.settings.states.bgn_arrest_time.help'] = 'Устанавливает время, отведенное на ваше задержание.',

	['bgn.settings.states.bgn_arrest_time_limit'] = 'Лимит времени на задержание',
	['bgn.settings.states.bgn_arrest_time_limit.help'] = 'Устанавливает, как долго полиция будет игнорировать вас во время ареста. Если вы откажетесь повиноваться по истеччению времени, они начнут вас атаковать.',

	['bgn.settings.states.bgn_shot_sound_mode'] = 'Включить реакцию на звуки выстрела',
	['bgn.settings.states.bgn_shot_sound_mode.help'] = 'NPC будут реагировать на звуки выстрела, как если бы кто-то стрелял по союзнику. (Предупреждение: функция эксперементальная и не рекомендуется к использованию)',

	['bgn.settings.states.bgn_cl_disable_self_halo_wanted'] = 'Отключить обводку локальной модели',
	['bgn.settings.states.bgn_cl_disable_self_halo_wanted.help'] = 'Отключает эффект обводки розыска только для вашей модели игрока.',

	['bgn.settings.states.bgn_cl_disable_halo'] = 'Отключить всю обводку локально',
	['bgn.settings.states.bgn_cl_disable_halo.help'] = 'Отключает все эффекты обводки розыска локально. Полезно, если вы испытывайте проблемы с производительностью или некорректной отрисовкой.',

	['bgn.settings.states.bgn_disable_halo_calling'] = 'Отключить обводку вызова полиции',
	['bgn.settings.states.bgn_disable_halo_calling.help'] = 'Отключает эффект обводки для актёров во время звонка в полицию.',

	['bgn.settings.states.bgn_disable_halo_wanted'] = 'Отключить обводку розыска',
	['bgn.settings.states.bgn_disable_halo_wanted.help'] = 'Отключает эффект обводки сущностей, находящихся в розыске.',

	['bgn.settings.states.bgn_cl_disable_hud_local'] = 'Отключить HUD розыска локально',
	['bgn.settings.states.bgn_cl_disable_hud_local.help'] = 'Отключает весь HUD розыска для локального игрока.',

	['bgn.settings.states.bgn_enable_dv_support'] = 'Включить поддержку аддона "DV"',
	['bgn.settings.states.bgn_enable_dv_support.help'] = 'Включает совместимость с аддоном "DV" и ззаставляет NPC использовать автотранспорт. Требуется чтобы в DV была включена автоматическая загрузка путей передвижения!',

	['bgn.settings.states.bgn_enable_police_system_support'] = 'Включить поддержку аддона "Система Полиции"',
	['bgn.settings.states.bgn_enable_police_system_support.help'] = 'Включает совместимость с аддоном "Система Полиции" и переопределяет стандартный метод ареста.',

	['bgn.settings.states.bgn_disable_dialogues'] = 'Отключить диалоги между NPC',
	['bgn.settings.states.bgn_disable_dialogues.help'] = 'Отключает общение NPC друг с другом.',

	['bgn.settings.states.bgn_module_replics_enable'] = 'Включить текстовые реплики',
	['bgn.settings.states.bgn_module_replics_enable.help'] = 'Включает текстовые реплики над головами NPC.',

	['bgn.settings.states.bgn_module_bio_annihilation_two_replacement'] = 'Включить поддержку Bio-Annihilation II',
	['bgn.settings.states.bgn_module_bio_annihilation_two_replacement.help'] = 'Включает автоматическую замену зомби на NPC из Bio-Annihilation II.',

	['bgn.settings.states.bgn_module_arccw_weapon_replacement'] = 'Включить поддержку ArcCW',
	['bgn.settings.states.bgn_module_arccw_weapon_replacement.help'] = 'Включает автоматическую замену на оружие из аддона ArcCW. Требуется чтобы в ArcCW тоже была включена замена оружия у NPC!',

	['bgn.settings.states.bgn_all_models_random'] = 'Включить рандом моделей',
	['bgn.settings.states.bgn_all_models_random.help'] = 'Все NPC будут появлятся со случайными моделями, которые будут взяты из общего игрового списка!',

	['bgn.settings.states.bgn_module_stormfox2'] = 'Включает поддержку StormFox2',
	['bgn.settings.states.bgn_module_stormfox2.help'] = 'Если на улице ночь или идёт дождь, то на карте будет в два раза меньше NPC.',

	['bgn.settings.states.bgn_module_custom_gestures'] = 'Расширенные анимации (ЭКСПЕРИМЕНТАЛЬНО)',
	['bgn.settings.states.bgn_module_custom_gestures.help'] = 'Включает поддержку расширенных анимаций. NPC будут танцевать, и делать больше различных действий. Отключите это, если оно создаёт проблемы.',

	['bgn.settings.states.bgn_module_tactical_groups'] = 'Тактические группы (ЭКСПЕРИМЕНТАЛЬНО)',
	['bgn.settings.states.bgn_module_tactical_groups.help'] = 'Включает тактические группы. В данный момент работает только с актёрами, которые состоят в группах "police" и "bandits". В перестрелках NPC будут пытаться собираться в тактические группы, чтобы стараться минимизировать урон по команде.',

	['bgn.settings.states.bgn_module_followers_mod_addon'] = 'Включить поддержку Followers Mod',
	['bgn.settings.states.bgn_module_followers_mod_addon.help'] = 'Включает поддержку аддона "Followers Mod", и даёт возможность заставить актёров следовать за вами.',
}