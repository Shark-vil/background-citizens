local EntityRemovedLock = false
local isfunction = isfunction
local IsValid = IsValid
--
local none_name = 'Gabe Newell'

local function GetEntityName(ent)
	if not IsValid(ent) or not isfunction(ent.GetName) then
		return none_name
	end

	local name = ent:GetName()
	local actor = bgNPC:GetActor(ent)

	if actor then
		name = actor:GetName()
	elseif name == '' and isfunction(ent.GetClass) then
		name = ent:GetClass()
	end

	if not name or name == '' then
		name = none_name
	end

	return name
end

local function GetEntityInflictorName(ent)
	local class

	if IsValid(ent) and isfunction(ent.GetActiveWeapon) then
		local weapon = ent:GetActiveWeapon()
		if IsValid(weapon) and isfunction(weapon.IsWeapon) and weapon:IsWeapon() and isfunction(weapon.GetClass) then
			class = weapon:GetClass()
		end
	end

	if not class and IsValid(ent) and isfunction(ent.GetClass) then
		class = ent:GetClass()
	end

	if not class or class == '' then
		class = none_name
	end

	return class
end

local function Call_BGN_OnKilledActor(actor, npc, attacker)
	actor.OnNPCKilled = true

	bgNPC:Log(tostring(attacker) .. ' killed ' .. actor:GetName(), 'OnNPCKilled')

	bgNPC:AddKillingStatistic(attacker, actor)
	-- bgNPC:AddWantedKillingStatistic(attacker, actor)

	hook.Run('BGN_OnKilledActor', actor, attacker)
end

hook.Add('PlayerDeath', 'BGN_OnPlayerDeath', function(victim, inflictor, attacker)
	attacker = bgNPC:CheckVehicleAttacker(attacker)
	if not attacker then return end

	local actor = bgNPC:GetActor(attacker)
	if not actor then return end

	local killed_data = {
		attacker = GetEntityName(attacker),
		team = -1,
		inflictor = GetEntityInflictorName(inflictor),
		victim = GetEntityName(victim),
		victimTeam = victim:Team(),
	}

	snet.InvokeAll('bgn_base_on_npc_killed_player', killed_data)
end)

hook.Add('OnNPCKilled', 'BGN_OnKilledActor', function(npc, attacker, inflictor)
	attacker = bgNPC:CheckVehicleAttacker(attacker)
	if not attacker then return end

	local actor = bgNPC:GetActor(npc)
	local killed_data

	if not actor and not bgNPC:GetActor(attacker) then return end

	killed_data = {
		attacker = GetEntityName(attacker),
		team = attacker:IsPlayer() and attacker:Team() or -1,
		inflictor = GetEntityInflictorName(inflictor),
		victim = GetEntityName(npc),
		victimTeam = -1,
	}

	if killed_data then
		snet.InvokeAll('bgn_base_on_npc_killed', killed_data)
	end

	if actor and not actor.OnNPCKilled and not EntityRemovedLock then
		Call_BGN_OnKilledActor(actor, npc, attacker)
	end
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
	local attacker = bgNPC:CheckVehicleAttacker(dmginfo:GetAttacker())
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