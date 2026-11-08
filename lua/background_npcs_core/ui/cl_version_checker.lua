local text_color_info = Color(61, 206, 217)
local text_color_red = Color(255, 0, 0)
local text_command_color = Color(227, 209, 11)
local text_version_color = Color(237, 153, 43)
local text_color_mod_title = Color(85, 180, 243)
local text_color_orange = Color(255, 196, 0)
local text_color_green = Color(30, 255, 0)
local text_color_version = Color(135, 196, 211)

-- -1 / 0 / 1 by each number: "2.0.0" is newer than "1.13.7" (gluing the digits, 200 < 1137, was not)
local function CompareVersions(a, b)
	local pa, pb = string.Explode('.', string.Trim(a)), string.Explode('.', string.Trim(b))
	for i = 1, math.max(#pa, #pb) do
		local x, y = tonumber(pa[i]) or 0, tonumber(pb[i]) or 0
		if x ~= y then return x < y and -1 or 1 end
	end
	return 0
end

local function version_check()
	http.Fetch('https://raw.githubusercontent.com/Shark-vil/background-citizens/master/version.txt',
		function(github_version, length, headers, code)
			if code ~= 200 or not github_version then
				bgNPC.Util.Log('Failed to check the actual version: error code\n' .. tostring(code), 'Version Checker')
				return
			end

			local ru_lang = {
				-- bye_text = 'Возможно это последнее обновление. Было весело. До встречи!\n',
				msg_outdated = 'Вы используете устаревшую версию \'Background NPCs\' :(\n',
				msg_latest = 'Вы используете последнюю версию \'Background NPCs\' :)\n',
				msg_dev = 'Вы используете версию для разработчиков \'Background NPCs\' :o\n',
				msg_upgrade = 'Аддон \'Background NPCs\' был обновлён до версии:\n',
				actual_version = 'Актуальная версия - ' .. github_version .. ' : Ваша версия - ' .. bgNPC.VERSION .. '\n',
				update_page_1 = 'Используйте консольную команду \'',
				update_page_2 = '\' чтобы посмотреть информацию о последнем выпуске.\n',
				command  = 'bgn_updateinfo'
			}

			local en_lang = {
				-- bye_text = 'This may be the last update. It was fun. See you!\n',
				msg_outdated = 'You are using an outdated version of \'Background NPCs\' :(\n',
				msg_latest = 'You are using the latest version of \'Background NPCs\' :)\n',
				msg_dev = 'You are using the dev version of \'Background NPCs\' :o\n',
				msg_upgrade = 'The \'Background NPCs\' addon has been updated to version:\n',
				actual_version = 'Actual version - ' .. github_version .. ' : Your version - ' .. bgNPC.VERSION .. '\n',
				update_page_1 = 'Use the console command \'',
				update_page_2 = '\' to view information about the latest release.\n',
				command  = 'bgn_updateinfo'
			}

			local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
			local compare = CompareVersions(bgNPC.VERSION, github_version)
			local v_storage = '[out of sync]'

			if file.Exists('background_npcs/version.txt', 'DATA') then
				v_storage = file.Read('background_npcs/version.txt', 'DATA')
			end

			if compare < 0 then

				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_orange, lang.msg_outdated, text_version_color, lang.actual_version,
					text_color_info, lang.update_page_1,
					text_command_color, lang.command, text_color_info, lang.update_page_2)

			elseif compare == 0 then

				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_green, lang.msg_latest, text_version_color, lang.actual_version,
					text_color_info, lang.update_page_1,
					text_command_color, lang.command, text_color_info, lang.update_page_2)

			else

				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_green, lang.msg_dev, text_version_color, lang.actual_version,
					text_color_info, lang.update_page_1,
					text_command_color, lang.command, text_color_info, lang.update_page_2)

			end

			-- chat.AddText(lang.bye_text)

			if v_storage ~= bgNPC.VERSION then
				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_version, lang.msg_upgrade,
					text_version_color, v_storage .. ' -> ' .. bgNPC.VERSION .. '\n')

				file.Write('background_npcs/version.txt', bgNPC.VERSION)
			end
		end,
		function(message)
			MsgN('[Background NPCs] Failed to check the actual version:\n' .. message)
		end
	)
end
concommand.Add('bgn_version_check', version_check)

hook.Add('BGN_PlayerReady', 'BGN_CheckAddonVersion', function(ply)
	if ply ~= LocalPlayer() then return end
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	chat.AddText(text_color_red, '[ADMIN] ', text_color_mod_title, 'Background NPCs: ', text_color_info,
		bgNPC.Phrases['bgn.classic.tip'] or language.GetPhrase('bgn.classic.tip'))
	version_check()
end)