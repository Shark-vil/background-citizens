if SERVER then
	snet.Callback('BGN_Nodes_RequestChunksFromTheServer', function(ply, data)
		local MAP_CHUNKS = BGN_NODE:GetChunkManager()
		snet.Request('BGN_Nodes_SendChunksDataToClient', MAP_CHUNKS:GetChunks())
			.ProgressText('Loading chunks from server')
			.Invoke(ply)
	end).Protect()
else
	local CHUNK_CLASS = slib.Component('Chunks')
	local MAP_CHUNKS = CHUNK_CLASS:Instance()

	snet.RegisterCallback('BGN_Nodes_SendChunksDataToClient', function(_, data)
		MAP_CHUNKS:SetChunks(data)
	end)

	hook.Add('slib.FirstPlayerSpawn', 'BGN_Nodes_RequestChunksFromTheServer', function()
		if not GetConVar('bgn_cl_draw_chunks'):GetBool() then return end
		snet.InvokeServer('BGN_Nodes_RequestChunksFromTheServer')
	end)

	cvars.AddChangeCallback('bgn_cl_draw_chunks', function(_, _, newValue)
		if tonumber(newValue) == 1 then
			snet.InvokeServer('BGN_Nodes_RequestChunksFromTheServer')
		else
			MAP_CHUNKS:SetChunks()
		end
	end, 'bgn_cl_draw_chunks_changed')

	concommand.Add('bgn_cl_draw_chunks_reload', function(ply)
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		if not GetConVar('bgn_cl_draw_chunks'):GetBool() then return end
		snet.InvokeServer('BGN_Nodes_RequestChunksFromTheServer')
	end)

	local angle_zero = Angle()
	local color_box_line = Color(255, 255, 255)
	local color_box = Color(236, 154, 243, 50)

	hook.Add('PostDrawTranslucentRenderables', 'BGN_Nodes_ChunkRenderer', function()
		if not IsValid(MAP_CHUNKS) then return end

		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		local chunk = MAP_CHUNKS:GetChunkByEntity(ply)
		if chunk then
			local center = chunk.center_pos
			local mins = WorldToLocal(center, angle_zero, chunk.start_pos, angle_zero)
			local maxs = WorldToLocal(center, angle_zero, chunk.end_pos, angle_zero)

			render.SetColorMaterial()
			render.DrawWireframeBox(center, angle_zero, mins, maxs, color_box_line)
			render.DrawBox(center, angle_zero, mins, maxs, color_box)
		end
	end)
end