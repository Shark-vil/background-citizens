if SERVER then
	hook.Add('PlayerDisconnected', 'Slib_PlayerDisconnectedRemoveLoadedPlayer', function(disconnected_player)
		if IsValid(disconnected_player) then
			local hook_name = disconnected_player.slib_first_spawn_hook_name
			if hook_name and isstring(hook_name) then
				hook.Remove('SetupMove', hook_name)
			end
		end

		for i = #slib.Storage.LoadedPlayers, 1, -1 do
			local ply = slib.Storage.LoadedPlayers[i]
			if not IsValid(ply) or ply == disconnected_player then
				slib.DebugLog('The player ', ply, ' has disconnected from the server')
				table.remove(slib.Storage.LoadedPlayers, i)
			end
		end

		snet.InvokeAll('slib_player_disconnected_sync', disconnected_player)
	end)

	hook.Add('PlayerSpawn', 'Slib_PlayerFirstSpawnFixer', function(ply)
		if ply.slib_player_spawn then return end
		ply.slib_player_spawn = true

		local hook_name = 'slib.FirstSpawnSetupMove_' .. slib.GetChecksumUID(ply:UserID())
		ply.slib_first_spawn_hook_name = hook_name

		hook.Add('SetupMove', hook_name, function(move_player, move_data, move_command)
			if not IsValid(ply) then
				hook.Remove('SetupMove', hook_name)
			elseif IsValid(move_player) and move_player == ply and not move_command:IsForced() then
				hook.Remove('SetupMove', hook_name)

				ply.snet_ready = true
				ply.slib_first_spawn_hook_name = nil

				table.insert(slib.Storage.LoadedPlayers, ply)

				local slib_hook = slib.Component('Hook')
				slib_hook.SafeRun('slib.FirstPlayerSpawn', ply)

				-- hook.Run('slib.FirstPlayerSpawn', ply)
				snet.InvokeAll('slib_first_player_spawn', ply)
				snet.Invoke('slib_first_player_spawn_sync', ply, slib.Storage.LoadedPlayers)
			end
		end)
	end)

	hook.Add('slib.FirstPlayerSpawn', 'Slib_SyncExistsNetworkVariable', function(ply)
		for _, ent in ipairs(ents.GetAll()) do
			if not IsValid(ent) or not ent.slibVariables then continue end
			for key, value in pairs(ent.slibVariables) do
				if value ~= nil then
					snet.Invoke('slib_entity_variable_set', ply, ent, key, value)
				end
			end
		end
	end)
else
	snet.Callback('slib_first_player_spawn', function(_, ply)
		slib.DebugLog('Player ', ply, ' first spawn on the server')

		if ply == LocalPlayer() then
			slib.DebugLog('You spawned on the server for the first time')
		end

		ply.snet_ready = true
		table.insert(slib.Storage.LoadedPlayers, ply)

		hook.Run('slib.FirstPlayerSpawn', ply)
	end).Validator(SNET_ENTITY_VALIDATOR)

	snet.Callback('slib_first_player_spawn_sync', function(_, players)
		for i = 1, #players do
			local ply = players[i]
			if not IsValid(ply) or ply == LocalPlayer() or ply.snet_ready then
				continue
			end

			ply.snet_ready = true
			table.insert(slib.Storage.LoadedPlayers, ply)

			slib.DebugLog('Player sync -', ply)
		end
	end).Validator(SNET_ENTITY_VALIDATOR)

	snet.Callback('slib_player_disconnected_sync', function(_, disconnected_player)
		for i = #slib.Storage.LoadedPlayers, 1, -1 do
			local ply = slib.Storage.LoadedPlayers[i]
			if not IsValid(ply) or ply == disconnected_player then
				slib.DebugLog('The player ', ply, ' has disconnected from the server')
				table.remove(slib.Storage.LoadedPlayers, i)
			end
		end
	end)
end