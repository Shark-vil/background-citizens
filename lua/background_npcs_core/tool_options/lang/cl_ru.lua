local target_directory = 'background_npcs_core/tool_options/lang/'
slib.usingDirectory(target_directory .. 'ru')

local lang = {}

table.Merge(lang, include(target_directory .. 'ru/cl_options.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_general.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_client.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_optimization.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_spawn.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_workshop.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_actors.lua'))
table.Merge(lang, include(target_directory .. 'ru/cl_modules.lua'))

return lang