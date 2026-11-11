-- The mod's own language (bgn_cl_ui_language): the game loads resource/localization/<gmod_language>/*.properties
-- by itself; another language is loaded here over it, file by file. language.Add doesn't replace a phrase the game
-- already loaded, so the phrases are also kept in bgNPC.Phrases, which the menu reads first (Menu.Text).
bgNPC.Phrases = {}
local function ApplyLanguage()
  local phrases = {}
  bgNPC.Phrases = phrases
  local legacy = bgNPC.Util.Lang({
    ['default'] = bgNPC.LANGUAGES['english'],
    ['russian'] = bgNPC.LANGUAGES['russian']
  })

  for k, v in pairs(legacy) do
    language.Add(k, v)
  end

  local code = bgNPC.Util.GetLanguage()
  if not file.Exists('resource/localization/' .. code .. '/bgn_menu.properties', 'GAME') then code = 'en' end
  local dir = 'resource/localization/' .. code .. '/'
  for _, name in ipairs(file.Find(dir .. 'bgn_*.properties', 'GAME')) do
    for line in (file.Read(dir .. name, 'GAME') or ''):gmatch('[^\r\n]+') do
      local key, value = line:match('^([%w_%.]+)=(.*)$')
      if key then
        phrases[key] = value
        language.Add(key, value)
      end
    end
  end
end

ApplyLanguage()
cvars.AddChangeCallback('bgn_cl_ui_language', ApplyLanguage, 'BGN_UILanguage')
cvars.AddChangeCallback('gmod_language', ApplyLanguage, 'BGN_UILanguage')
