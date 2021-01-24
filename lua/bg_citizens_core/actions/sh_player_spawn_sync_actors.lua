if SERVER then
	hook.Add("PlayerSpawn", "BGN_SyncActorsOnPlayerSpawn", function(ply)
		if ply.BGN_IsLoaded then return end
		
		timer.Simple(3, function()
			if not IsValid(ply) then return end

			for _, actor in ipairs(bgNPC:GetAll()) do
				if actor:IsAlive() then
					local type = actor:GetType()
					local npc = actor:GetNPC()

					if IsValid(npc) then
						bgNPC:TemporaryVectorVisibility(npc, 3)

						timer.Simple(1, function()
							if not IsValid(npc) or not IsValid(ply) then return end

							net.InvokeAll('bgn_add_actor_from_client', type, npc)

							timer.Simple(1.5, function()
								if not IsValid(npc) or not IsValid(ply) then return end

								actor:SyncData()
								bgNPC.Log('Actor [' .. type .. '] - ' .. tostring(npc), ' | Player - ' .. tostring(ply), 'Sync Actors')
							end)
						end)
					end
				end
			end
		end)

		ply.BGN_IsLoaded = true
		net.Invoke('bgn_is_loaded_setup', ply)
	end)
else
	net.RegisterCallback('bgn_is_loaded_setup', function()
		LocalPlayer().BGN_IsLoaded = true
		MsgN('!!!!!!!!!! BGN_IsLoaded !!!!!!!!!!')
	end)
end