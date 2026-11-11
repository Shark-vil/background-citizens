-- Spawn menu -> Options -> Background NPCs: the tab and the category. The pages are in cl_classic_settings.lua.
hook.Add('AddToolMenuTabs', 'BGN_TOOL_CreateOptionsCategory', function() spawnmenu.AddToolTab('Options', '#Options') end)
hook.Add('AddToolMenuCategories', 'BGN_TOOL_CreateOptionsCategory', function() spawnmenu.AddToolCategory('Options', 'Background NPCs', '#bgn.menu.title') end)
