local pairs = pairs
local table_RandomBySeq = table.RandomBySeq
local hook_Run = hook.Run
local slib_chance = slib.chance
--
local cvar_bgn_module_replics_enable = GetConVar('bgn_module_replics_enable')

timer.Create('BGN_Timer_StateRandomizeReplics', 10, 0, function()
	if not cvar_bgn_module_replics_enable:GetBool() then return end

	local actors = bgNPC:GetAll()

	for i = 1, #actors do
		local actor = actors[i]
		if not actor or not actor:IsAlive() or actor:InVehicle() or not slib_chance(15) then
			continue
		end

		local data = actor:GetData()
		if not data or not data.replics then continue end

		if data.replics.state_names then
			for state_name, replics_id in pairs(data.replics.state_names) do
				if bgNPC.cfg.replics[replics_id] and actor:HasState(state_name) then
					local _, replic_index = table_RandomBySeq(bgNPC.cfg.replics[replics_id])
					actor:SayReplic(replics_id, replic_index)
					hook_Run('BGN_StartReplic', actor, replics_id, replic_index, 10)
					continue
				end
			end
		end

		if data.replics.state_groups then
			for group_name, replics_id in pairs(data.replics.state_groups) do
				if bgNPC.cfg.replics[replics_id] and actor:EqualStateGroup(group_name) then
					local _, replic_index = table_RandomBySeq(bgNPC.cfg.replics[replics_id])
					actor:SayReplic(replics_id, replic_index)
					hook_Run('BGN_StartReplic', actor, replics_id, replic_index, 10)
					continue
				end
			end
		end
	end
end)