snet.Callback('slib_player_set_language', function(ply, player_language)
	local code, lang = slib.GetLanguageCode(player_language)
	if code and lang then
		ply:slibSetVar('slib_client_language', lang)
		ply:slibSetVar('slib_client_language_code', code)
		return
	end

	ply:slibSetVar('slib_client_language', 'english')
	ply:slibSetVar('slib_client_language_code', 'en')
end).Period(1, 2)