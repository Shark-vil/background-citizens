local target_directory = 'background_npcs_core/tool_options/lang/'
slib.usingDirectory(target_directory .. 'en')

local lang = {}

table.Merge(lang, include(target_directory .. 'en/cl_options.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_general.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_client.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_optimization.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_spawn.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_workshop.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_actors.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_modules.lua'))

return lang