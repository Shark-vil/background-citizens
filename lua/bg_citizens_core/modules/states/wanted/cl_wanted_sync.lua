local asset = bgNPC:GetModule('wanted')

net.RegisterCallback('bgn_module_wanted_AddWanted', function(_, ent)
    print('[BGN Module][Wanted]', 'AddWanted Sync')
    asset:AddWanted(ent)
end)

net.RegisterCallback('bgn_module_wanted_RemoveWanted', function(_, ent)
    print('[BGN Module][Wanted]', 'RemoveWanted Sync')
    asset:RemoveWanted(ent)
end)

net.RegisterCallback('bgn_module_wanted_UpdateWanted', function(_, ent)
    if asset:HasWanted(ent) then
        print('[BGN Module][Wanted]', 'UpdateWanted Sync')

        local c_Wanted = asset:GetWanted(ent)
        c_Wanted:UpdateWanted()
    end
end)

net.RegisterCallback('bgn_module_wanted_UpdateWaitTime', function(_, ent, time)
    if asset:HasWanted(ent) then
        print('[BGN Module][Wanted]', 'UpdateWaitTime Sync')

        local c_Wanted = asset:GetWanted(ent)
        c_Wanted:UpdateWaitTime(time)
    end
end)