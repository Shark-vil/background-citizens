hook.Add("OnNPCKilled", "BGN_OnKilledActor", function(npc, attacker, inflictor)
	local actor = bgNPC:GetActor(npc)
	if actor then
		bgNPC:AddKillingStatistic(attacker, actor)
		bgNPC:AddWantedKillingStatistic(attacker, actor)
		
		hook.Run('BGN_OnKilledActor', actor, attacker)
	end
end)

hook.Add("BGN_OnKilledActor", "BGN_DelayActorRespawn", function(actor)
	local data = actor:GetData()
	if data.respawn_delay ~= nil then
		local actor_type = actor:GetType()

		bgNPC.respawn_actors_delay[actor_type] = bgNPC.respawn_actors_delay[actor_type] or {
			count = 0,
			time = 0,
		}

		local count = bgNPC.respawn_actors_delay[actor_type].count
		bgNPC.respawn_actors_delay[actor_type].count = count + 1
		
		if bgNPC.respawn_actors_delay[actor_type].time < CurTime() then
			bgNPC.respawn_actors_delay[actor_type].time = CurTime() + data.respawn_delay
		end
	end
end)