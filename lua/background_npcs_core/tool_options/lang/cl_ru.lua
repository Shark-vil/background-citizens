slib.usingDirectory('background_npcs_core/tool_options/ru')

local lang = {}

table.Merge(lang, include('ru/cl_options.lua'))
table.Merge(lang, include('ru/cl_general.lua'))
table.Merge(lang, include('ru/cl_client.lua'))
table.Merge(lang, include('ru/cl_optimization.lua'))
table.Merge(lang, include('ru/cl_spawn.lua'))
table.Merge(lang, include('ru/cl_workshop.lua'))
table.Merge(lang, include('ru/cl_actors.lua'))
table.Merge(lang, include('ru/cl_modules.lua'))

return lang