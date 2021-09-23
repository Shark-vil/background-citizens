scvar.Register('bgn_map_gm_construct_remove_darkroom_points', 1,
FCVAR_ARCHIVE, 'Removes movement points from the darkroom. 1 - enabled, 0 - disabled.')
.Access({ isAdmin = true })

if SERVER then
	local startPosDarkRoom = Vector( -3236, -2567, 205 )
	local endPosDarkRoom = Vector( -5250, -1052, -168 )

	hook.Add('BGN_PostLoadRoutes', 'BGN_GmConstrcutFixedDarkRoom', function()
		if not tobool( string.find( game.GetMap(), 'gm_construct' ) ) then return end
		if slib.CvarCheckValue('bgn_map_gm_construct_remove_darkroom_points', 0) then return end
		if hook.Run('BGN_Map_GmConstruct_Remove_DarkRoom_Points') then return end
		if not BGN_NODE.Map or #BGN_NODE.Map == 0 then return end

		for i = #BGN_NODE.Map, 1, -1 do
			local node = BGN_NODE.Map[i]
			if node and node:GetPos():WithinAABox( startPosDarkRoom, endPosDarkRoom ) then
				node:RemoveFromMap()
			end
		end
	end)
end