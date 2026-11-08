local text_color_info = Color(61, 206, 217)
local text_color_red = Color(255, 0, 0)
local text_color_mod_title = Color(85, 180, 243)
local text_color_orange = Color(255, 196, 0)
local text_color_green = Color(30, 255, 0)
local text_color_gray = Color(200, 200, 200)

-- -1 / 0 / 1 by each number: "2.0.0" is newer than "1.13.7" (gluing the digits, 200 < 1137, was not)
local function CompareVersions(a, b)
	local pa, pb = string.Explode('.', string.Trim(a)), string.Explode('.', string.Trim(b))
	for i = 1, math.max(#pa, #pb) do
		local x, y = tonumber(pa[i]) or 0, tonumber(pb[i]) or 0
		if x ~= y then return x < y and -1 or 1 end
	end
	return 0
end

local function Phrase(key, ...)
	return string.format(bgNPC.Phrases[key] or language.GetPhrase(key), ...)
end

-- One chat line per fact: "[ADMIN] Background NPCs: text"
local function Say(color, text)
	chat.AddText(text_color_red, '[ADMIN] ', text_color_mod_title, 'Background NPCs: ', color, text)
end

-- done() is called after the version lines (also when the check failed), so the tip always comes last
local function version_check(done)
	http.Fetch('https://raw.githubusercontent.com/Shark-vil/background-citizens/master/version.txt',
		function(github_version, length, headers, code)
			if code ~= 200 or not github_version then
				bgNPC.Util.Log('Failed to check the actual version: error code: ' .. tostring(code), 'Version Checker')
			else
				github_version = string.Trim(github_version)
				local compare = CompareVersions(bgNPC.VERSION, github_version)

				if compare < 0 then
					Say(text_color_orange, Phrase('bgn.version.outdated', github_version, bgNPC.VERSION))
				elseif compare == 0 then
					Say(text_color_green, Phrase('bgn.version.latest', bgNPC.VERSION))
				else
					Say(text_color_info, Phrase('bgn.version.dev', bgNPC.VERSION, github_version))
				end

				local v_storage = file.Exists('background_npcs/version.txt', 'DATA') and file.Read('background_npcs/version.txt', 'DATA')
				if v_storage and v_storage ~= bgNPC.VERSION then
					Say(text_color_green, Phrase('bgn.version.upgraded', v_storage, bgNPC.VERSION))
				end
				if v_storage ~= bgNPC.VERSION then file.Write('background_npcs/version.txt', bgNPC.VERSION) end
			end
			if done then done() end
		end,
		function(message)
			MsgN('[Background NPCs] Failed to check the actual version: ' .. message)
			if done then done() end
		end
	)
end
concommand.Add('bgn_version_check', function() version_check() end)

hook.Add('BGN_PlayerReady', 'BGN_CheckAddonVersion', function(ply)
	if ply ~= LocalPlayer() then return end
	if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
	version_check(function() Say(text_color_gray, Phrase('bgn.classic.tip')) end)
end)
