local ru_lang = {
	msg_outdated = "Вы используете устаревшую версию \"Background NPCs\" :(\n",
	msg_latest = "Вы используете последнюю версию \"Background NPCs\" :)\n",
	msg_dev = "Вы используете версию для разработчиков \"Background NPCs\" :o\n",
	actual_version = "Актуальная версия - " .. github_version .. " : Ваша версия - " .. bgNPC.VERSION .. "\n",
	update_page_1 = "Используйте консольную команду \"",
	update_page_2 = "\" чтобы посмотреть информацию о последнем выпуске.\n",
	command  = "bgn_updateinfo"
}

local en_lang = {
	msg_outdated = "You are using an outdated version of \"Background NPCs\" :(\n",
	msg_latest = "You are using the latest version of \"Background NPCs\" :)\n",
	msg_dev = "You are using the dev version of \"Background NPCs\" :o\n",
	actual_version = "Actual version - " .. github_version .. " : Your version - " .. bgNPC.VERSION .. "\n",
	update_page_1 = "Use the console command \"",
	update_page_2 = "\" to view information about the latest release.\n",
	command  = "bgn_updateinfo"
}

local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
local text_color_info = Color(61, 206, 217)
local text_command_color = Color(227, 209, 11)
local text_version_color = Color(237, 153, 43)

hook.Add('SlibPlayerFirstSpawn', 'BGN_CheckAddonVersion', function(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

	timer.Simple(3, function()
		http.Fetch('https://raw.githubusercontent.com/Shark-vil/background-citizens/master/version.txt',
			function(github_version, length, headers, code)
				if code ~= 200 then
					bgNPC:Log('Failed to check the actual version: error code\n' .. tostring(code), 'Version Checker')
					return
				end

				local v_github = tonumber(string.Replace(github_version, '.', ''))
				local v_addon = tonumber(string.Replace(bgNPC.VERSION, '.', ''))

				if v_addon < v_github then

					local text_color = Color(255, 196, 0)
					chat.AddText(Color(255, 0, 0), '[ADMIN] ',
						text_color, lang.msg_outdated, text_version_color, lang.actual_version, 
						text_color_info, lang.update_page_1,
						text_command_color, lang.command, text_color_info, lang.update_page_2)

				elseif v_addon == v_github then

					local text_color = Color(30, 255, 0)
					chat.AddText(Color(255, 0, 0), '[ADMIN] ',
						text_color, lang.msg_latest, text_version_color, lang.actual_version, 
						text_color_info, lang.update_page_1,
						text_command_color, lang.command, text_color_info, lang.update_page_2)

				elseif v_addon > v_github then

					local text_color = Color(30, 255, 0)
					chat.AddText(Color(255, 0, 0), '[ADMIN] ',
						text_color, lang.msg_dev, text_version_color, lang.actual_version, 
						text_color_info, lang.update_page_1,
						text_command_color, lang.command, text_color_info, lang.update_page_2)

				end
			end,
			function(message)
				MsgN('[Background NPCs] Failed to check the actual version:\n' .. message)
			end
		)
	end)
end)