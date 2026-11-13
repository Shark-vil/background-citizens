hook.Add('slib.FirstPlayerSpawn', 'BGN_LegacyUnsupportedNotice', function()
	local text = slib.language({
		['default'] = {
			['message'] = 'This version (Legacy 1.13.x) is no longer supported: no updates will be released and bugs will not be fixed.',
		},
		['russian'] = {
			['message'] = 'Эта версия (Legacy 1.13.x) больше не поддерживается: обновления выходить не будут, ошибки исправляться не будут.',
		},
	})

	timer.Simple(3, function()
		chat.AddText(Color(85, 180, 243), 'Background NPCs: ', Color(255, 196, 0), text['message'])
	end)
end)
