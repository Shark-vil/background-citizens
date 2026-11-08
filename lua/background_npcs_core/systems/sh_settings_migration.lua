--[[
	One-time return to the old behavior for the settings the 2.x versions turned on by themselves:
	ghost crowd (server and client), and the NextBot body / GOAP brain when they were left on "auto".
	Whoever picked "New" in the mode window (it sets the revision to 1) keeps the choice.
	The revision is the cvar bgn_settings_rev (server) and bgn_cl_settings_rev (client): 0 - not migrated yet.
--]]

if SERVER then
	hook.Add('InitPostEntity', 'BGN_SettingsMigration', function()
		local rev = GetConVar('bgn_settings_rev')
		if not rev or rev:GetInt() >= 1 then return end

		RunConsoleCommand('bgn_ghost_crowd', '0')
		-- an explicit "nextbot" / "goap" stays, only the old automatic choice goes back
		if GetConVar('bgn_actor_body'):GetString() == 'auto' then RunConsoleCommand('bgn_actor_body', 'npc') end
		if GetConVar('bgn_brain'):GetString() == 'auto' then RunConsoleCommand('bgn_brain', 'fsm') end
		RunConsoleCommand('bgn_settings_rev', '1')
	end)
else
	local cvar_rev = CreateClientConVar('bgn_cl_settings_rev', '0', true, false, 'Internal: client settings revision. Do not change.')

	hook.Add('InitPostEntity', 'BGN_SettingsMigration', function()
		if cvar_rev:GetInt() >= 1 then return end
		RunConsoleCommand('bgn_cl_settings_rev', '1')

		local chosen = GetConVar('bgn_mode_chosen')
		local mode = GetConVar('bgn_mode')
		if chosen and mode and chosen:GetBool() and mode:GetString() == 'new' then return end
		RunConsoleCommand('bgn_cl_ghost_crowd', '0')
	end)
end
