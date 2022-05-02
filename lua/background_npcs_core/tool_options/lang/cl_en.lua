slib.usingDirectory('background_npcs_core/tool_options/en')

local lang = {}

table.Merge(lang, include('en/cl_options.lua'))
table.Merge(lang, include('en/cl_general.lua'))
table.Merge(lang, include('en/cl_client.lua'))
table.Merge(lang, include('en/cl_optimization.lua'))
table.Merge(lang, include('en/cl_spawn.lua'))
table.Merge(lang, include('en/cl_workshop.lua'))
table.Merge(lang, include('en/cl_actors.lua'))
table.Merge(lang, include('en/cl_modules.lua'))

return lang