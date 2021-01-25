if SERVER then
	util.AddNetworkString('network_bgn_client_first_initializate')

	net.Receive('network_bgn_client_first_initializate', function(len, ply)
		if ply.BGN_IsLoaded then return end

		local sync_time = 2

		for _, actor in ipairs(bgNPC:GetAll()) do
			if actor:IsAlive() then
				local type = actor:GetType()
				local npc = actor:GetNPC()
				bgNPC:TemporaryVectorVisibility(npc, 3 + (sync_time - 2))

				timer.Simple(sync_time, function()
					if not IsValid(npc) or not IsValid(ply) then return end

					net.InvokeAll('bgn_add_actor_from_client', type, npc)

					timer.Simple(0.5, function()
						if not IsValid(npc) or not IsValid(ply) then return end

						actor:SyncData()
						bgNPC.Log('Actor [' .. type .. '] - ' .. tostring(npc) .. ' | Player - ' .. tostring(ply), 'Sync Actors')
					end)
				end)
				
				sync_time = sync_time + 0.05
			end
		end

		net.Invoke('bgn_is_loaded_setup', ply)

		ply.BGN_IsLoaded = true

		hook.Run('BGN_PlayerIsLoaded', ply)
	end)
else
	hook.Add("InitPostEntity", "BGN_ClientFirstInitializate", function()
		timer.Simple(1, function()
			net.Start('network_bgn_client_first_initializate')
			net.SendToServer()
		end)
		hook.Remove("InitPostEntity", "BGN_ClientFirstInitializate")
	end)

	net.RegisterCallback('bgn_is_loaded_setup', function()
		LocalPlayer().BGN_IsLoaded = true
	end)
end