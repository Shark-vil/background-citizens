local asset = bgNPC:GetModule('wanted')

snet.RegisterCallback('bgn_module_wanted_AddWanted', function(_, ent)
	bgNPC:Log('AddWanted Sync', 'Module | Wanted')
	asset:AddWanted(ent)
end)

snet.RegisterCallback('bgn_module_wanted_RemoveWanted', function(_, ent)
	bgNPC:Log('RemoveWanted Sync', 'Module | Wanted')
	asset:RemoveWanted(ent)
end)

snet.RegisterCallback('bgn_module_wanted_UpdateWanted', function(_, ent)
	if asset:HasWanted(ent) then
		bgNPC:Log('UpdateWanted Sync', 'Module | Wanted')

		local c_Wanted = asset:GetWanted(ent)
		c_Wanted:UpdateWanted()
	end
end)

snet.RegisterCallback('bgn_module_wanted_UpdateWaitTime', function(_, ent, time)
	if asset:HasWanted(ent) then
		bgNPC:Log('UpdateWaitTime Sync', 'Module | Wanted')

		local c_Wanted = asset:GetWanted(ent)
		c_Wanted:UpdateWaitTime(time)
	end
end)

snet.RegisterCallback('bgn_module_wanted_UpdateLevel', function(_, ent, level)
	if asset:HasWanted(ent) then
		bgNPC:Log('UpdateLevel Sync', 'Module | Wanted')

		local c_Wanted = asset:GetWanted(ent)
		c_Wanted.level = level
	end
end)