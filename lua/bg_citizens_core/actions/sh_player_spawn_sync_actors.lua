if SERVER then
	hook.Add("PlayerSpawn", "BGN_PlayerFirstInitSpawnerHook", function(ply)
		timer.Simple(3, function()
			if not IsValid(ply) or ply.BGN_IsLoaded then return end

			bgNPC:Log('Pre first spawn', 'PlayerSpawner')

			local sync_time = 2

			for _, actor in ipairs(bgNPC:GetAll()) do
				if actor:IsAlive() then
					local type = actor:GetType()
					local npc = actor:GetNPC()
					bgNPC:TemporaryVectorVisibility(npc, 3 + (sync_time - 2))

					timer.Simple(sync_time, function()
						if not IsValid(npc) or not IsValid(ply) then return end

						snet.InvokeAll('bgn_add_actor_from_client', type, npc)

						timer.Simple(0.5, function()
							if not IsValid(npc) or not IsValid(ply) then return end

							actor:SyncData(ply)
							bgNPC.Log('Actor [' .. type .. '] - ' .. tostring(npc) .. ' | Player - ' .. tostring(ply), 'Sync Actors')
						end)
					end)
					
					sync_time = sync_time + 0.05
				end
			end

			hook.Run('BGN_PlayerIsLoaded', ply)
			ply.BGN_IsLoaded = true

			timer.Simple(1, function()
				if not IsValid(ply) then return end
				snet.Invoke('bgn_is_loaded_setup', ply)
			end)

			bgNPC:Log('Post first spawn', 'PlayerSpawner')
		end)
	end)
else
	snet.RegisterCallback('bgn_is_loaded_setup', function()
		bgNPC:Log('Pre first spawn', 'PlayerSpawner')

		LocalPlayer().BGN_IsLoaded = true
		hook.Run('BGN_PlayerIsLoaded', LocalPlayer())

		bgNPC:Log('Post first spawn', 'PlayerSpawner')
	end)
end