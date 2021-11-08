local EntityRemovedLock = false

local function Call_BGN_OnKilledActor(actor, npc, attacker)
	bgNPC:Log(tostring(attacker) .. ' killed ' .. actor:GetName(), 'OnNPCKilled')

	bgNPC:AddKillingStatistic(attacker, actor)
	bgNPC:AddWantedKillingStatistic(attacker, actor)

	hook.Run('BGN_OnKilledActor', actor, attacker)
end

hook.Add('OnNPCKilled', 'BGN_OnKilledActor', function(npc, attacker)
	local actor = bgNPC:GetActor(npc)
	if not actor then return end

	actor.OnNPCKilled = true
	Call_BGN_OnKilledActor(actor, npc, attacker)
end)

hook.Add('EntityRemoved', 'BGN_OnKilledActorByRemoved', function(npc)
	local actor = bgNPC:GetActor(npc)
	if not actor or actor.OnNPCKilled or not actor.EntityTakeDamageInfo or EntityRemovedLock then
		return
	end

	local attacker = actor.EntityTakeDamageInfo.dmginfo:GetAttacker()
	if not IsValid(attacker) then return end

	Call_BGN_OnKilledActor(actor, npc, attacker)
end)

hook.Add('EntityTakeDamage', 'BGN_OnKilledActorByRemoved', function(target, dmginfo)
	local actor = bgNPC:GetActor(target)
	if not actor then return end

	actor.EntityTakeDamageInfo = actor.EntityTakeDamageInfo or {}
	actor.EntityTakeDamageInfo.target = target
	actor.EntityTakeDamageInfo.dmginfo = dmginfo
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