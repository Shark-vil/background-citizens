if SERVER then
	slib.RegisterDupeHandler('BGN_NODES_LOADER', 'BGN_NODES', function(ply, data)
		BGN_NODE:SetMap(BGN_NODE:JsonToMap(data))
		snet.Invoke('cl_bgn_dupe_is_load', ply)
	end)
else
	snet.Callback('cl_bgn_dupe_is_load', function()
		notification.AddLegacy('The movement mesh has been loaded!', NOTIFY_GENERIC, 4)
	end)

	snet.Callback('cl_bgn_save_dupe_nodes', function(_, json_nodes)
		slib.SaveDupe('BGN_NODES', json_nodes)
	end)
end

scommand.Create('bgn_save_map').OnServer(function(ply)
	if not IsValid(ply) then return end
	snet.Invoke('cl_bgn_save_dupe_nodes', ply, BGN_NODE:MapToJson())
end).Access({ isAdmin = true }).Register()