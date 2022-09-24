local EntityRemovedLock = false

local function Call_BGN_OnKilledActor(actor, npc, attacker)
	actor.OnNPCKilled = true

	bgNPC:Log(tostring(attacker) .. ' killed ' .. actor:GetName(), 'OnNPCKilled')

	bgNPC:AddKillingStatistic(attacker, actor)
	bgNPC:AddWantedKillingStatistic(attacker, actor)

	hook.Run('BGN_OnKilledActor', actor, attacker)
end


hook.Add('PlayerDeath', 'BGN_OnPlayerDeath', function(victim, inflictor, attacker)
	local actor = bgNPC:GetActor(attacker)
	if not actor then return end

	local killed_data = {
		attacker = actor:GetName(),
		team = -1,
		inflictor = inflictor:GetClass(),
		victim = victim:GetName(),
		victimTeam = victim:Team(),
	}

	snet.InvokeAll('bgn_base_on_npc_killed_player', killed_data)
end)

hook.Add('OnNPCKilled', 'BGN_OnKilledActor', function(npc, attacker, inflictor)
	local actor = bgNPC:GetActor(npc)
	if not actor or actor.OnNPCKilled or EntityRemovedLock then return end

	Call_BGN_OnKilledActor(actor, npc, attacker)

	local killed_data = {
		attacker = attacker:GetName(),
		team = attacker:IsPlayer() and attacker:Team() or -1,
		inflictor = inflictor:GetClass(),
		victim = actor:GetName(),
		victimTeam = (attacker:IsPlayer() and actor:HasTeam(attacker)) and attacker:Team() or -1,
	}

	snet.InvokeAll('bgn_base_on_npc_killed', killed_data)
end)

hook.Add('EntityRemoved', 'BGN_OnKilledActorByRemoved', function(npc)
	local actor = bgNPC:GetActor(npc)
	if not actor or actor.OnNPCKilled or not actor._onKilledActorLastDamageAttacker or EntityRemovedLock then
		return
	end

	local attacker = actor._onKilledActorLastDamageAttacker
	if not IsValid(attacker) then return end

	Call_BGN_OnKilledActor(actor, npc, attacker)
end)

hook.Add('EntityTakeDamage', 'BGN_OnKilledActorByRemoved', function(target, dmginfo)
	local actor = bgNPC:GetActor(target)
	if not actor then return end
	local attacker = dmginfo:GetAttacker()
	if not IsValid(attacker) or attacker == target then return end
	actor._onKilledActorLastDamageAttacker = attacker
end)

hook.Add('PreCleanupMap', 'BGN_OnKilledActorLock', function(npc)
	EntityRemovedLock = true
end)

hook.Add('PostCleanupMap', 'BGN_OnKilledActorUnlock', function(npc)
	EntityRemovedLock = false
end)

hook.Add('BGN_OnKilledActor', 'BGN_DelayActorRespawn', function(actor)
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