--
local asset = bgNPC.Modules.Get('wanted')
bgNPC.Net.Receive('bgn_module_wanted_AddWanted', function(_, ent, time)
  -- bgNPC.Util.Log('AddWanted Sync', 'Module | Wanted')
  asset:AddWanted(ent, time)
end, {
  wait_entities = true
})

bgNPC.Net.Receive('bgn_module_wanted_RemoveWanted', function(_, ent)
  -- bgNPC.Util.Log('RemoveWanted Sync', 'Module | Wanted')
  asset:RemoveWanted(ent)
end, {
  wait_entities = true
})

bgNPC.Net.Receive('bgn_module_wanted_UpdateWanted', function(_, ent, time)
  if asset:HasWanted(ent) then
    -- bgNPC.Util.Log('UpdateWanted Sync', 'Module | Wanted')
    local WantedClass = asset:GetWanted(ent)
    WantedClass:UpdateWanted(time)
  end
end, {
  wait_entities = true
})

bgNPC.Net.Receive('bgn_module_wanted_UpdateWaitTime', function(_, ent, time)
  if asset:HasWanted(ent) then
    -- bgNPC.Util.Log('UpdateWaitTime Sync', 'Module | Wanted')
    local WantedClass = asset:GetWanted(ent)
    WantedClass:UpdateWaitTime(time)
  end
end, {
  wait_entities = true
})

bgNPC.Net.Receive('bgn_module_wanted_UpdateLevel', function(_, ent, level)
  if asset:HasWanted(ent) then
    -- bgNPC.Util.Log('UpdateLevel Sync', 'Module | Wanted')
    local WantedClass = asset:GetWanted(ent)
    WantedClass.level = level
  end
end, {
  wait_entities = true
})
