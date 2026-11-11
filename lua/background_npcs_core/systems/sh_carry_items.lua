-- Native carry weapons drive locomotion; body adapters exclude them from the combat weapon API.
local Carry = bgNPC.CarryItems or { active = {} }
bgNPC.CarryItems = Carry

Carry.items = {
	ration = { model = 'models/weapons/w_package.mdl', weapon = 'weapon_citizenpackage', pocket = true,
		idle = 'idlepackage', walk = 'walk_holding_package_all', idle_act = ACT_IDLE_PACKAGE, walk_act = ACT_WALK_PACKAGE },
	suitcase = { model = 'models/weapons/w_suitcase_passenger.mdl', weapon = 'weapon_citizensuitcase',
		drop_model = 'models/props_c17/suitcase_passenger_physics.mdl',
		idle = 'd1_t01_Luggage_Idle', walk = 'luggage_walk_all', idle_act = ACT_IDLE_SUITCASE, walk_act = ACT_WALK_SUITCASE },
}

function Carry.Supports(ent, kind)
	local def = Carry.items[kind]
	return def and IsValid(ent) and ent:LookupSequence(def.idle) >= 0 and ent:LookupSequence(def.walk) >= 0
end

function Carry.Roll(ent, actor_type, data, supported)
	data = data or bgNPC.Config.GetActor(actor_type)
	local config = data and data.carry_items
	local enabled = GetConVar('bgn_carry_items_' .. actor_type)
	if not istable(config) or (enabled and not enabled:GetBool()) or math.Rand(0, 100) >= (config.chance or 0) then return end
	local candidates = {}
	for _, kind in ipairs(config.items or {}) do
		if (supported and supported[kind]) or (not supported and Carry.Supports(ent, kind)) then candidates[#candidates + 1] = kind end
	end
	if #candidates > 0 then return candidates[math.random(#candidates)] end
end

function Carry.Sequence(ent, kind, moving)
	local def = Carry.items[kind]
	return def and ent:LookupSequence(moving and def.walk or def.idle) or -1
end

function Carry.CreateVisual(ent, kind)
	local def = Carry.items[kind]
	if not def then return end
	local prop = CLIENT and ClientsideModel(def.model) or ents.Create('prop_dynamic')
	if not IsValid(prop) then return end
	if SERVER then prop:SetModel(def.model) prop:Spawn() end
	prop:SetParent(ent)
	prop:AddEffects(EF_BONEMERGE)
	prop:SetLocalPos(vector_origin)
	prop:SetLocalAngles(angle_zero)
	prop:SetSolid(SOLID_NONE)
	if SERVER then ent:DeleteOnRemove(prop) end
	if CLIENT then
		prop.RenderOverride = function(self)
			local parent = self:GetParent()
			local alpha = IsValid(parent) and parent.bgn_ghost_alpha or 0
			render.SetBlend(alpha) self:DrawModel() render.SetBlend(1)
		end
	end
	return prop
end

function Carry.Drop(kind, pos, ang, lifetime)
	local def = Carry.items[kind]
	if not def then return end
	local model = def.drop_model or def.model
	local prop = CLIENT and ClientsideModel(model) or ents.Create('prop_physics')
	if not IsValid(prop) then return end
	if SERVER then prop:SetModel(model) end
	prop:SetPos(pos)
	prop:SetAngles(ang or angle_zero)
	if SERVER then prop:Spawn() prop:SetCollisionGroup(COLLISION_GROUP_WORLD)
	else
		local floor = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 128), mask = MASK_SOLID_BRUSHONLY })
		if floor.Hit then prop:SetPos(floor.HitPos + Vector(0, 0, 1 - prop:OBBMins().z)) end
	end
	SafeRemoveEntityDelayed(prop, math.max(1, lifetime or 30))
	return prop
end

if CLIENT then return end

local function Compatible(actor)
	local state = actor:GetState()
	return not actor:InVehicle() and not actor:IsAnimationPlayed() and not actor:HasActiveWeapon()
		and (state == 'none' or state == 'walk' or state == 'idle' or state == 'dialogue')
end

function Carry.Remove(actor, drop)
	local item = Carry.active[actor]
	if not item then return end
	if IsValid(item.prop) then item.prop:Remove() end
	Carry.active[actor], actor.carry_item = nil, nil
	if not drop then return end
	local def = Carry.items[item.kind]
	local npc = actor:GetNPC()
	local pos = item.pos or actor:GetPos()
	if IsValid(npc) then
		local bone = npc:LookupBone('ValveBiped.Bip01_R_Hand')
		pos = bone and npc:GetBonePosition(bone) or npc:WorldSpaceCenter()
	end
	local prop = Carry.Drop(item.kind, pos, IsValid(npc) and npc:GetAngles(), item.lifetime)
	if IsValid(prop) and actor.scenic_debug_item then table.insert(actor.scenic_debug_item.props, prop) end
	return prop
end

function Carry.Attach(actor, kind)
	local npc = actor:GetNPC()
	if not actor:IsAlive() or actor:InVehicle() or not Carry.Supports(npc, kind) then return false end
	Carry.Remove(actor)
	local prop = actor:GetBody():GiveWeapon(Carry.items[kind].weapon)
	if not IsValid(prop) then return false end
	prop.bgn_carried_item = kind
	local config = actor:GetData().carry_items
	Carry.active[actor] = { kind = kind, prop = prop, pos = npc:GetPos(),
		lifetime = istable(config) and math.max(1, config.drop_lifetime or 30) or 30 }
	actor.carry_item = kind
	return true
end

function Carry.Suspend(actor)
	local item = Carry.active[actor]
	if not item then return end
	if Carry.items[item.kind].pocket then
		if IsValid(item.prop) then item.prop:Remove() end
	else Carry.Remove(actor, true) end
end

hook.Add('BGN_PreSetState', 'BGN_CarryItems', function(actor, state)
	if state ~= 'none' and state ~= 'walk' and state ~= 'idle' and state ~= 'dialogue' then Carry.Suspend(actor) end
end)
hook.Add('BGN_OnEnterVehicle', 'BGN_CarryItems', Carry.Suspend)

hook.Add('BGN_InitActor', 'BGN_CarryItems', function(actor)
	timer.Simple(0.1, function()
		if not actor:IsAlive() or actor.skip_auto_carry or actor.carry_initialized or actor.weapon then return end
		actor.carry_initialized = true
		local kind = Carry.Roll(actor:GetNPC(), actor:GetType(), actor:GetData())
		if kind and not actor:InVehicle() and actor:HasNoEnemies() and (actor:GetState() == 'none' or actor:EqualStateGroup('calm')) then
			actor:SetState('walk', nil, true)
			Carry.Attach(actor, kind)
		end
	end)
end)

hook.Add('Think', 'BGN_CarryItems', function()
	for actor, item in pairs(Carry.active) do
		if not actor:IsAlive() then Carry.Remove(actor) continue end
		local npc, def = actor:GetNPC(), Carry.items[item.kind]
		if not Compatible(actor) then
			Carry.Suspend(actor)
			continue
		end
		if not Carry.Supports(npc, item.kind) then Carry.Remove(actor, not def.pocket) continue end
		if not IsValid(item.prop) then
			item.prop = actor:GetBody():GiveWeapon(def.weapon)
			if IsValid(item.prop) then item.prop.bgn_carried_item = item.kind end
		end
		if npc:IsNPC() then
			-- Engine NPCs can move with zero GetVelocity; derive motion from positions across their slower AI ticks.
			if npc:GetPos():DistToSqr(item.pos) > 0.01 then item.walk_until = CurTime() + 0.2 end
			local act = (item.walk_until or 0) > CurTime() and def.walk_act or def.idle_act
			if npc:GetActivity() ~= act then npc:SetActivity(act) npc:SetCycle(item.cycle or 0) end
			item.cycle = npc:GetCycle()
		end
		item.pos = npc:GetPos()
	end
end)

hook.Add('BGN_OnKilledActor', 'BGN_CarryItems', function(actor)
	local item = Carry.active[actor]
	if item then Carry.Remove(actor, not Carry.items[item.kind].pocket) end
end)
