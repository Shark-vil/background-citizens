-- NextBots use carry weapons for locomotion; engine NPCs keep their normal AI and a client-only briefcase.
local Carry = bgNPC.CarryItems or { active = {} }
bgNPC.CarryItems = Carry

Carry.items = {
	ration = { model = 'models/weapons/w_package.mdl', weapon = 'weapon_citizenpackage', pocket = true,
		idle = 'idlepackage', walk = 'walk_holding_package_all', idle_act = ACT_IDLE_PACKAGE, walk_act = ACT_WALK_PACKAGE },
	suitcase = { model = 'models/weapons/w_suitcase_passenger.mdl', weapon = 'weapon_citizensuitcase',
		npc_model = 'models/props_c17/briefcase001a.mdl',
		drop_model = 'models/props_c17/suitcase_passenger_physics.mdl',
		idle = 'd1_t01_Luggage_Idle', walk = 'luggage_walk_all', idle_act = ACT_IDLE_SUITCASE, walk_act = ACT_WALK_SUITCASE },
	newspaper = { model = 'models/props_junk/garbage_newspaper001a.mdl', weapon = 'weapon_citizenpackage', pocket = true, visual = true,
		idle = 'idlepackage', walk = 'walk_holding_package_all' },
}

function Carry.Supports(ent, kind, ghost)
	local def = Carry.items[kind]
	if not def or not IsValid(ent) then return false end
	if not ghost and ent:IsNPC() then
		return def.npc_model ~= nil and ent:LookupBone('ValveBiped.Bip01_R_Hand') ~= nil
	end
	if kind == 'newspaper' and (not ent:LookupBone('ValveBiped.Bip01_R_Hand') or not ent:LookupBone('ValveBiped.Bip01_L_Hand')) then return false end
	return ent:LookupSequence(def.idle) >= 0 and ent:LookupSequence(def.walk) >= 0
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

function Carry.CreateVisual(ent, kind, native)
	local def = Carry.items[kind]
	if not def then return end
	local prop = ClientsideModel(native and def.npc_model or def.model)
	if not IsValid(prop) then return end
	prop:SetParent(ent)
	if native then
		local bone = ent:LookupBone('ValveBiped.Bip01_R_Hand')
		if not bone then prop:Remove() return end
	elseif kind ~= 'newspaper' then
		prop:AddEffects(EF_BONEMERGE)
	end
	prop:SetLocalPos(vector_origin)
	prop:SetLocalAngles(angle_zero)
	prop:SetSolid(SOLID_NONE)
	prop.RenderOverride = function(self)
		local parent = self:GetParent()
		if not IsValid(parent) or parent:GetNoDraw() then return end
		if native then
			local bone = parent:LookupBone('ValveBiped.Bip01_R_Hand')
			local hand = bone and parent:GetBoneMatrix(bone)
			if not hand then return end
			local pos, ang = LocalToWorld(Vector(11, 0, 0), Angle(-90, 0, 0), hand:GetTranslation(), hand:GetAngles())
			self:SetRenderOrigin(pos) self:SetRenderAngles(ang)
		elseif kind == 'newspaper' then
			local rb, lb = parent:LookupBone('ValveBiped.Bip01_R_Hand'), parent:LookupBone('ValveBiped.Bip01_L_Hand')
			local right, left = rb and parent:GetBoneMatrix(rb), lb and parent:GetBoneMatrix(lb)
			if not right or not left then return end
			right, left = right:GetTranslation(), left:GetTranslation()
			local across = left - right
			if across:LengthSqr() < 1 then return end
			local width = math.Clamp(across:Length(), 14, 26)
			local normal = parent:GetForward()
			across = across - normal * across:Dot(normal)
			if across:LengthSqr() < 1 then across = -parent:GetRight() end
			self:SetRenderOrigin((right + left) * 0.5 + Vector(0, 0, 6))
			self:SetRenderAngles(across:AngleEx(normal))
			local scale = Matrix() scale:Scale(Vector(width / 24, 0.65, 0.2))
			self:EnableMatrix('RenderMultiply', scale)
		end
		render.SetBlend(parent.bgn_ghost_alpha or 1) self:DrawModel() render.SetBlend(1)
	end
	return prop
end

function Carry.Drop(kind, pos, ang, lifetime, model)
	local def = Carry.items[kind]
	if not def then return end
	model = model or def.drop_model or def.model
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
	local npc = actor:GetNPC()
	return not actor:InVehicle() and not actor:IsAnimationPlayed() and not actor:HasActiveWeapon()
		and not (npc.IsBGNNextBot and npc.move_run)
		and (state == 'none' or state == 'walk' or state == 'idle' or state == 'dialogue')
end

function Carry.Remove(actor, drop)
	local item = Carry.active[actor]
	if not item then return end
	if IsValid(item.prop) then item.prop:Remove() end
	Carry.active[actor], actor.carry_item, actor.carry_visual = nil, nil, nil
	if not drop then return end
	local npc = actor:GetNPC()
	local pos = item.pos or actor:GetPos()
	if IsValid(npc) then
		local bone = npc:LookupBone('ValveBiped.Bip01_R_Hand')
		pos = bone and npc:GetBonePosition(bone) or npc:WorldSpaceCenter()
	end
	local prop = Carry.Drop(item.kind, pos, IsValid(npc) and npc:GetAngles(), item.lifetime, item.drop_model)
	if IsValid(prop) and actor.scenic_debug_item then table.insert(actor.scenic_debug_item.props, prop) end
	return prop
end

local function Equip(actor, item)
	local npc, def = actor:GetNPC(), Carry.items[item.kind]
	if npc.IsBGNNextBot then
		item.prop = actor:GetBody():GiveWeapon(def.weapon)
		if not IsValid(item.prop) then return false end
		item.prop.bgn_carried_item = item.kind
		item.prop:SetNoDraw(def.visual == true)
	end
	item.visible = true
	actor.carry_visual = (npc:IsNPC() or def.visual) and item.kind or nil
	return true
end

function Carry.Attach(actor, kind)
	local npc = actor:GetNPC()
	if not actor:IsAlive() or actor:InVehicle() or not Carry.Supports(npc, kind) then return false end
	Carry.Remove(actor)
	local config = actor:GetData().carry_items
	local item = { kind = kind, pos = npc:GetPos(), drop_model = npc:IsNPC() and Carry.items[kind].npc_model or nil,
		lifetime = istable(config) and math.max(1, config.drop_lifetime or 30) or 30 }
	if not Equip(actor, item) then return false end
	Carry.active[actor] = item
	actor.carry_item = kind
	return true
end

function Carry.Suspend(actor)
	local item = Carry.active[actor]
	if not item then return end
	if Carry.items[item.kind].pocket then
		if IsValid(item.prop) then item.prop:Remove() end
		item.visible, actor.carry_visual = false, nil
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
		if not item.visible or (npc.IsBGNNextBot and not IsValid(item.prop)) then Equip(actor, item) end
		item.pos = npc:GetPos()
	end
end)

hook.Add('BGN_OnKilledActor', 'BGN_CarryItems', function(actor)
	local item = Carry.active[actor]
	if item then Carry.Remove(actor, not Carry.items[item.kind].pocket) end
end)
