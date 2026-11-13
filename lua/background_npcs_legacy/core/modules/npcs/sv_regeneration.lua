async.Add('BGN_ActorsRegeneration', function(yield, wait)
	local math_Clamp = math.Clamp
	local CurTime = CurTime
	local EFL_NO_THINK_FUNCTION = EFL_NO_THINK_FUNCTION

	while true do
		local actors = bgNPC:GetAll()

		for i = 1, #actors do
			local actor = actors[i]

			if actor and actor:IsAlive() and not actor:GetNPC():IsEFlagSet(EFL_NO_THINK_FUNCTION) then
				local actor_data = actor:GetData()
				if actor_data.regeneration then
					actor._last_regeneration_update_time = actor._last_regeneration_update_time or 0
					if actor._last_regeneration_update_time < CurTime() then
						local npc = actor:GetNPC()
						local regeneration_time = 1 or actor_data.regeneration_time
						local max_health = npc:GetMaxHealth() or actor_data.regeneration_max_health
						local current_health = npc:Health()
						local new_health = math_Clamp(current_health + 1, 0, max_health)
						npc:SetHealth(new_health)
						actor._last_regeneration_update_time = CurTime() + regeneration_time
					end
				end
			end

			yield()
		end

		yield()
	end
end)