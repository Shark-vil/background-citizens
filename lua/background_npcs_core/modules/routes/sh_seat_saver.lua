if SERVER then
	hook.Add('InitPostEntity', 'BGN_InitializeAllSeats', function()
		BGN_SEAT:Initialize()
	end)

	snet.RegisterCallback('sv_bgn_tool_seat_save', function(ply, points)
			local save_data = util.Compress(util.TableToJSON(points))
			file.Write('background_npcs/seats/' .. game.GetMap() .. '.dat', save_data)
			BGN_SEAT:Initialize()
	end, false, true)

	local function ReadSeatData()
		local file_path = 'background_npcs/seats/' .. game.GetMap() .. '.dat'

		if file.Exists(file_path, 'DATA') then
			local read_data = util.JSONToTable(util.Decompress(file.Read(file_path, 'DATA')))
			return read_data
		end

		return {}
	end

	snet.RegisterCallback('sv_bgn_tool_seat_load', function(ply, points)
		local data = ReadSeatData()

		if #data ~= 0 then
			snet.Invoke('cl_bgn_tool_seat_load', ply, data)
		end
	end, false, true)

	snet.RegisterCallback('sv_bgn_tool_seat_compile', function(ply, points)
		local data = ReadSeatData()
		snet.Invoke('cl_bgn_tool_seat_compile', ply, data)
	end, false, true)
else
	snet.RegisterCallback('cl_bgn_tool_seat_load', function(ply, points)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end
		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
		if not tool then return end

		for _, t in ipairs(tool.SeatPoints) do
			if t.m_citizen then
				t.m_citizen:Remove()
			end
		end

		tool.SeatPoints = {}

		for _, t in ipairs(points) do
			local m_citizen = ClientsideModel('models/Humans/Group01/male_02.mdl')
			m_citizen:SetSequence('Sit_Chair')
			m_citizen:Spawn()

			table.insert(tool.SeatPoints, {
				data = {
					start_pos = t.start_pos,
					position = t.position,
					offset = t.offset,
					angle = t.angle,
				},
				m_citizen = m_citizen,
			})
		end
	end)

	snet.RegisterCallback('cl_bgn_tool_seat_compile', function(ply, points)
		hook.Run('BGN_LoadingClienSeats', points)
	end)

	concommand.Add('bgn_tool_seat_compile', function()
		local ply = LocalPlayer()
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		snet.Invoke('sv_bgn_tool_seat_compile')
	end)

	concommand.Add('bgn_tool_seat_load', function()
		local ply = LocalPlayer()
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end
		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
		if not tool then return end
		snet.Invoke('sv_bgn_tool_seat_load')
	end)

	concommand.Add('bgn_tool_seat_save', function()
		local ply = LocalPlayer()
		if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end
		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
		if not tool then return end
		local points = {}

		for _, t in ipairs(tool.SeatPoints) do
			if t.data.position then
				table.insert(points, t.data)
			end
		end

		snet.Invoke('sv_bgn_tool_seat_save', nil, points)
	end)
end