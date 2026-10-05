local bgNPC = bgNPC
--
local asset = bgNPC.Modules.Get('wanted')

snet.Callback('bgn_module_wanted_AddWanted', function(_, ent)
	-- bgNPC.Util.Log('AddWanted Sync', 'Module | Wanted')
	asset:AddWanted(ent)
end).Validator(SNET_ENTITY_VALIDATOR)

snet.Callback('bgn_module_wanted_RemoveWanted', function(_, ent)
	-- bgNPC.Util.Log('RemoveWanted Sync', 'Module | Wanted')
	asset:RemoveWanted(ent)
end).Validator(SNET_ENTITY_VALIDATOR)

snet.Callback('bgn_module_wanted_UpdateWanted', function(_, ent)
	if asset:HasWanted(ent) then
		-- bgNPC.Util.Log('UpdateWanted Sync', 'Module | Wanted')

		local WantedClass = asset:GetWanted(ent)
		WantedClass:UpdateWanted()
	end
end).Validator(SNET_ENTITY_VALIDATOR)

snet.Callback('bgn_module_wanted_UpdateWaitTime', function(_, ent, time)
	if asset:HasWanted(ent) then
		-- bgNPC.Util.Log('UpdateWaitTime Sync', 'Module | Wanted')

		local WantedClass = asset:GetWanted(ent)
		WantedClass:UpdateWaitTime(time)
	end
end).Validator(SNET_ENTITY_VALIDATOR)

snet.Callback('bgn_module_wanted_UpdateLevel', function(_, ent, level)
	if asset:HasWanted(ent) then
		-- bgNPC.Util.Log('UpdateLevel Sync', 'Module | Wanted')

		local WantedClass = asset:GetWanted(ent)
		WantedClass.level = level
	end
end).Validator(SNET_ENTITY_VALIDATOR)