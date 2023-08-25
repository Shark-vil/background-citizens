local target_directory = 'background_npcs_core/tool_options/lang/'
slib.usingDirectory(target_directory .. 'en', nil, true)

if SERVER then return end

local lang = {}

table.Merge(lang, include(target_directory .. 'en/cl_options.lua'))
table.Merge(lang, include(target_directory .. 'en/cl_actors.lua'))

bgNPC.LANGUAGES['english'] = lang