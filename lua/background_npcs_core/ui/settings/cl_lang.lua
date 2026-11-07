local lang = bgNPC.Util.Lang({
	['default'] = bgNPC.LANGUAGES['english'],
	['russian'] = bgNPC.LANGUAGES['russian']
})

for k, v in pairs(lang) do
	language.Add(k, v)
end