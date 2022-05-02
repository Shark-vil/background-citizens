local ru_lang = include('lang/cl_ru.lua')
local en_lang = include('lang/cl_en.lua')

local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
for k, v in pairs(lang) do
	language.Add(k, v)
end