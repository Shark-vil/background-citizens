hook.Add("OnNPCKilled", "BGN_OnKilledActor", function(npc, attacker, inflictor)
	local actor = bgNPC:GetActor(npc)
	if actor ~= nil then
		bgNPC:AddKillingStatistic(attacker, actor)
		hook.Run('BGN_OnKilledActor', actor, attacker)
	end
end)

hook.Add("BGN_OnKilledActor", "BGN_DelayActorRespawn", function(actor)
	local data = actor:GetData()
	if data.respawn_delay ~= nil then
		bgNPC.respawn_actors_delay[actor:GetType()] = bgNPC.respawn_actors_delay[actor:GetType()] or {
			count = 0,
			time = 0,
		}

		local count = bgNPC.respawn_actors_delay[actor:GetType()].count
		bgNPC.respawn_actors_delay[actor:GetType()].count = count + 1
		
		if bgNPC.respawn_actors_delay[actor:GetType()].time < CurTime() then
			bgNPC.respawn_actors_delay[actor:GetType()].time = CurTime() + data.respawn_delay
		end
	end
end)