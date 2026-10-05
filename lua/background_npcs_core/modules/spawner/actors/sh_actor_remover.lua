hook.Add('PostCleanupMap', 'BGN_ResetAllGlobalTablesAndVariables', function()
	bgNPC:ClearActorsConfig()
	bgNPC.actors = {}
	bgNPC.factors = {}
	bgNPC.npcs = {}
	bgNPC.fnpcs = {}
	bgNPC.actors_by_uid = {}
end)

cvars.AddChangeCallback('bgn_enable', function(convar_name, value_old, value_new)
	if tonumber(value_new) == 0 then
		bgNPC:ClearActorsConfig()
	end
end)