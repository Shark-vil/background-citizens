local function IsReduceLimit()
	if not StormFox2 then return false end
	return StormFox2.Weather.IsRaining() or StormFox2.Time.IsNight()
end

timer.Create('BGN_Stormfox_Humans_Limits', 1, 0, function()
	if not IsReduceLimit() then return end

	for _, actor in ipairs(bgNPC:GetAll()) do
		if actor and actor:IsAlive() then
			local npc_type = actor:GetType()
			if bgNPC:Count(npc_type) > math.Round(bgNPC:GetLimitActors(npc_type) / 2) then
				actor.toRemove = true
			end
		end
	end
end)

hook.Add('BGN_OnValidSpawnActor', 'BGN_Stormfox_TimeLimit', function(npc_type)
	if not IsReduceLimit() then return end

	local next_count = bgNPC:Count(npc_type) + 1
	local spawn_limit = math.Round(bgNPC:GetLimitActors(npc_type) / 2)

	if next_count > spawn_limit then
		return true
	end
end)