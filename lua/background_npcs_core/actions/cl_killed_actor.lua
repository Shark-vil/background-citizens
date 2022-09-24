hook.Add('OnGamemodeLoaded', 'BGN_Override_AddDeathNotice', function()
	local AddDeathNotice = GAMEMODE.AddDeathNotice
	local is_ignore = false

	function GAMEMODE:AddDeathNotice(attacker, attackerTeam, inflictor, victim, victimTeam)
		if is_ignore then
			is_ignore = false
			return
		end

		return AddDeathNotice(GAMEMODE, attacker, attackerTeam, inflictor, victim, victimTeam)
	end

	snet.RegisterCallback('bgn_base_on_npc_killed', function(_, data)
		GAMEMODE:AddDeathNotice(data.attacker, data.team, data.inflictor, data.victim, data.victimTeam)

		is_ignore = true

		timer.Simple(.1, function()
			if is_ignore then is_ignore = false end
		end)
	end)

	snet.RegisterCallback('bgn_base_on_npc_killed_player', function(_, data)
		GAMEMODE:AddDeathNotice(data.attacker, data.team, data.inflictor, data.victim, data.victimTeam)

		is_ignore = true

		timer.Simple(.1, function()
			if is_ignore then is_ignore = false end
		end)
	end)
end)