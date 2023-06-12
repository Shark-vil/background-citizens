snet.RegisterCallback('bgn_dynamic_mevement_mesh_alert_message', function()
	local _, lang_code = LocalPlayer():slibGetLanguage()
	local text_color_red = Color(255, 0, 0)
	local text_color = Color(255, 196, 0)
	local text_color_mod_title = Color(85, 180, 243)
	local text_color_green = Color(30, 255, 0)
	local message, options_message

	if lang_code == 'ru' then
		message = 'Dключен генератор сетки перемещения в реальном времени.\n'
		message = message .. 'Если у вас возникли проблемы с производительностью, вы можете изменить настройки в спавнменю:\n'
		options_message = 'Options > Background NPCs > Генерация\n'
	else
		message = 'Realtime movement mesh generator is enabled.\n'
		message = message .. 'If you have performance problems, you can change the settings in the spawnmenu:\n'
		options_message = 'Options > Background NPCs > Generations\n'
	end

	chat.AddText(text_color_red, '[ADMIN] ',
		text_color_mod_title, 'Background NPCs:\n',
		text_color, message,
		text_color_green, options_message .. '\n')
end)