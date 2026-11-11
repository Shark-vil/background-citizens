bgNPC.States.Register('knocked_down', 'danger')
if CLIENT then return end

local OFFSETS = { Vector() }
for _, radius in ipairs({ 32, 64, 96 }) do
	for i = 0, 7 do OFFSETS[#OFFSETS + 1] = Vector(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4), 0) * radius end
end

local function StandPosition(actor, data)
	local npc, rag = actor:GetNPC(), data.ragdoll
	local origin = IsValid(rag) and rag:GetPos() or data.origin
	local mins, maxs = npc:GetCollisionBounds()
	for _, offset in ipairs(OFFSETS) do
		local pos = origin + offset
		local floor = util.TraceLine({ start = pos + Vector(0, 0, 36), endpos = pos - Vector(0, 0, 96),
			mask = MASK_NPCSOLID, filter = { npc, rag } })
		if floor.Hit and not floor.StartSolid and floor.HitNormal.z >= 0.95 then
			pos = floor.HitPos + Vector(0, 0, 2 - math.min(mins.z, 0))
			local room = util.TraceHull({ start = pos, endpos = pos, mins = mins, maxs = maxs,
				mask = MASK_NPCSOLID, filter = { npc, rag } })
			if not room.Hit and not room.StartSolid then return pos end
		end
	end
end

local function Restore(actor, data)
	if data.restored then return end
	data.restored, data.releasing = true, true
	local npc = actor:GetNPC()
	if IsValid(npc) and data.saved then
		local saved = data.saved
		npc:SetPos(data.stand or data.origin)
		npc:SetAngles(Angle(0, saved.ang.y, 0))
		npc:SetMoveType(saved.move_type)
		npc:SetSolidFlags(saved.solid_flags)
		npc:SetCollisionGroup(saved.collision_group)
		npc:SetNoDraw(saved.no_draw)
		npc:SetNW2Bool('bgn_knocked_down', false)
		if not saved.no_target then npc:RemoveFlags(FL_NOTARGET) end
		for weapon, hidden in pairs(saved.weapons) do if IsValid(weapon) then weapon:SetNoDraw(hidden) end end
		actor.mechanics.use_vehicle = saved.use_vehicle
		actor:GetBody():SetThinkEnabled(saved.think_enabled)
		actor:GetBody():StopSequence()
		npc:RemoveCallOnRemove('BGN_KnockedDown')
	end
	if IsValid(data.ragdoll) then data.ragdoll:Remove() end
end

local function CreateRagdoll(actor)
	local npc = actor:GetNPC()
	local rag = ents.Create('prop_ragdoll')
	if not IsValid(rag) then return end
	rag:SetModel(npc:GetModel())
	rag:SetPos(npc:GetPos())
	rag:SetAngles(npc:GetAngles())
	rag:SetSkin(npc:GetSkin())
	rag:SetModelScale(npc:GetModelScale(), 0)
	rag:SetColor(npc:GetColor())
	rag:SetMaterial(npc:GetMaterial())
	for _, group in ipairs(npc:GetBodyGroups()) do rag:SetBodygroup(group.id, npc:GetBodygroup(group.id)) end
	for i = 0, #npc:GetMaterials() - 1 do rag:SetSubMaterial(i, npc:GetSubMaterial(i)) end
	rag:Spawn()
	if rag:GetPhysicsObjectCount() == 0 then rag:Remove() return end
	rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	for i = 0, rag:GetPhysicsObjectCount() - 1 do
		local phys = rag:GetPhysicsObjectNum(i)
		local bone = rag:TranslatePhysBoneToBone(i)
		local pos, ang = npc:GetBonePosition(bone)
		if IsValid(phys) and pos and ang then phys:SetPos(pos) phys:SetAngles(ang) end
	end
	return rag
end

bgNPC.States.Register('knocked_down', 'danger', {
	pre_start = function(actor, _, data)
		if actor:InVehicle() or actor:HasState('knocked_down') then return true end
		data.resume = data.resume or actor:GetState()
		data.ragdoll = CreateRagdoll(actor)
		if not data.ragdoll then return true end
	end,
	start = function(actor, _, data)
		local npc, body = actor:GetNPC(), actor:GetBody()
		local weapons = npc.GetWeapons and npc:GetWeapons() or { actor:GetActiveWeapon() }
		data.origin = npc:GetPos()
		data.saved = { move_type = npc:GetMoveType(), solid_flags = npc:GetSolidFlags(), collision_group = npc:GetCollisionGroup(),
			no_draw = npc:GetNoDraw(), no_target = npc:IsFlagSet(FL_NOTARGET), ang = npc:GetAngles(), weapons = {},
			use_vehicle = actor.mechanics.use_vehicle, think_enabled = body:IsThinkEnabled() }
		for _, weapon in ipairs(weapons) do
			if IsValid(weapon) then data.saved.weapons[weapon] = weapon:GetNoDraw() weapon:SetNoDraw(true) end
		end
		actor.mechanics.use_vehicle = false
		body:PlaySequence(npc:GetSequence())
		body:SetThinkEnabled(false)
		npc:SetMoveType(MOVETYPE_NONE)
		npc:SetNotSolid(true)
		npc:AddFlags(FL_NOTARGET)
		npc:SetNoDraw(true)
		npc:SetNW2Bool('bgn_knocked_down', true)
		data.wake_at = CurTime() + 3
		data.ragdoll.bgn_knocked_actor = actor
		for i = 0, data.ragdoll:GetPhysicsObjectCount() - 1 do
			local phys = data.ragdoll:GetPhysicsObjectNum(i)
			if IsValid(phys) then phys:SetVelocity(data.velocity or vector_origin) phys:Wake() end
		end
		npc:CallOnRemove('BGN_KnockedDown', function() Restore(actor, data) end)
		data.ragdoll:CallOnRemove('BGN_KnockedDown', function()
			if not data.releasing and not actor.is_removed then actor:Remove() end
		end)
	end,
	not_stop = function(_, _, data) return not data.releasing end,
	stop = function(actor, _, data) Restore(actor, data) end,
	update = function(actor, _, data)
		if not IsValid(data.ragdoll) then actor:Remove() return end
		actor:GetNPC():SetPos(data.ragdoll:GetPos())
		if CurTime() < data.wake_at then return end
		data.wake_at = CurTime() + 0.25
		data.stand = StandPosition(actor, data)
		if not data.stand then return end -- remain down until a standing hull fits
		data.releasing = true
		actor:SetState(actor:HasNoEnemies() and 'none' or data.resume, nil, true)
	end,
})

-- Forced reactions must not uncover the frozen body before a safe stand-up position exists.
hook.Add('BGN_PreSetState', 'BGN_KnockedDown', function(actor)
	if actor:HasState('knocked_down') and not actor:GetStateData().releasing then return true end
end)

hook.Add('EntityTakeDamage', 'BGN_KnockedDown', function(target, damage)
	local actor = target.bgn_knocked_actor
	if actor and actor:IsAlive() and actor:HasState('knocked_down') then
		-- The knock and its physics contacts do not add damage; attacks on the visible body still do.
		if not damage:IsDamageType(DMG_CRUSH) then actor:GetNPC():TakeDamageInfo(damage) end
		return true
	end
	actor = bgNPC.Actors.Get(target)
	if actor and actor:HasState('knocked_down') and damage:GetDamage() >= actor:Health() then
		Restore(actor, actor:GetStateData()) -- ordinary death creates the real corpse, not an invisible one
	end
end)

hook.Add('BGN_OnKilledActor', 'BGN_KnockedDown', function(actor)
	if actor:HasState('knocked_down') then Restore(actor, actor:GetStateData()) end
end)
