local text_color_info = Color(61, 206, 217)
local text_color_red = Color(255, 0, 0)
local text_command_color = Color(227, 209, 11)
local text_version_color = Color(237, 153, 43)
local text_color_mod_title = Color(85, 180, 243)
local text_color_orange = Color(255, 196, 0)
local text_color_green = Color(30, 255, 0)
local text_color_version = Color(135, 196, 211)

local function version_check()
	http.Fetch('https://raw.githubusercontent.com/Shark-vil/background-citizens/master/version.txt',
		function(github_version, length, headers, code)
			if code ~= 200 or not github_version then
				bgNPC:Log('Failed to check the actual version: error code\n' .. tostring(code), 'Version Checker')
				return
			end

			local ru_lang = {
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
			local v_github = tonumber(string.Replace(github_version, '.', ''))
			local v_addon = tonumber(string.Replace(bgNPC.VERSION, '.', ''))
			local v_storage = '[out of sync]'

			if file.Exists('background_npcs/version.txt', 'DATA') then
				v_storage = file.Read('background_npcs/version.txt', 'DATA')
			end

			if v_addon < v_github then

				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_orange, lang.msg_outdated, text_version_color, lang.actual_version,
					text_color_info, lang.update_page_1,
					text_command_color, lang.command, text_color_info, lang.update_page_2 .. '\n')

			elseif v_addon == v_github then

				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_green, lang.msg_latest, text_version_color, lang.actual_version,
					text_color_info, lang.update_page_1,
					text_command_color, lang.command, text_color_info, lang.update_page_2 .. '\n')

			elseif v_addon > v_github then

				chat.AddText(text_color_red, '[ADMIN] ',
					text_color_mod_title, 'Background NPCs:\n',
					text_color_green, lang.msg_dev, text_version_color, lang.actual_version,
					text_color_info, lang.update_page_1,
					text_command_color, lang.command, text_color_info, lang.update_page_2 .. '\n')

			end

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

hook.Add('slib.FirstPlayerSpawn', 'BGN_CheckAddonVersion', function(ply)
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	version_check()
end)