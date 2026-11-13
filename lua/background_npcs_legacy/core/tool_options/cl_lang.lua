local lang = slib.language({
	['default'] = bgNPC.LANGUAGES['english'],
	['russian'] = bgNPC.LANGUAGES['russian']
})

for k, v in pairs(lang) do
	language.Add(k, v)
end