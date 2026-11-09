local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
--

-- ---------------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------------
local function ResolveVehicleGroup(actor)
	local vehicle_group = actor.data.vehicle_group
	if vehicle_group then return vehicle_group end
	if actor:HasTeam('police') then return 'police' end
	if actor:HasTeam('taxi') then return 'taxi' end
	return nil
end

-- @return string the group of the cars this actor drives: 'police', 'bandits', ... or 'residents'
function Actor:GetVehicleGroup()
	return string.Explode('|', ResolveVehicleGroup(self) or 'residents')[1]
end

local function CaptureBody(actor)
	-- shortcut: addon-private NPC state needs its own BGN_ActorEntityChanged handler when restored.
	local npc = actor:GetNPC()
	local mins, maxs = npc:GetCollisionBounds()
	local saved = {
		class = npc:GetClass(), npc_class = npc.bgn_npc_class, model = npc:GetModel(),
		skin = npc:GetSkin(), scale = npc:GetModelScale(), color = npc:GetColor(), material = npc:GetMaterial(),
		collision_group = npc:GetCollisionGroup(), mins = mins, maxs = maxs,
		health = npc:Health(), max_health = npc:GetMaxHealth(), keyvalues = npc:GetKeyValues(),
		bodygroups = {}, weapons = {}, eternal = actor.eternal,
		proficiency = npc.GetCurrentWeaponProficiency and npc:GetCurrentWeaponProficiency(),
		bot_clip = npc.IsBGNNextBot and npc.clip or nil,
	}
	for _, group in ipairs(npc:GetBodyGroups()) do saved.bodygroups[group.id] = npc:GetBodygroup(group.id) end
	local active = actor:GetActiveWeapon()
	saved.active_weapon = IsValid(active) and active:GetClass() or nil
	local weapons = npc.GetWeapons and npc:GetWeapons() or { active }
	if IsValid(active) and not table.HasValue(weapons, active) then weapons[#weapons + 1] = active end
	for _, weapon in ipairs(weapons) do
		if IsValid(weapon) then
			saved.weapons[#saved.weapons + 1] = { class = weapon:GetClass(), clip1 = weapon:Clip1(), clip2 = weapon:Clip2() }
		end
	end
	return saved
end

function Actor:EnterVehicle(vehicle)
	Assert.Arg(1, vehicle, 'entity', 'ACTOR:EnterVehicle')
	if not self.mechanics.use_vehicle or not DecentVehicleDestination then return end
	if not IsValid(vehicle) or not vehicle:IsVehicle() or self:InVehicle() then return end
	local provider = BGN_VEHICLE:GetVehicleProvider(vehicle)
	if not provider then
		provider = BGN_VEHICLE:Instance(vehicle, ResolveVehicleGroup(self), self:GetType())
		if not provider then return end
		BGN_VEHICLE:AddToList(provider)
	end
	if not provider:CanUse(self) then return end

	-- Each actor owns its pending request; simultaneous passenger requests must not replace each other.
	bgNPC.Util.EntityTimer(vehicle, 'bgn_actor_enter_vehicle_' .. self.uid, .5, 1, function(car)
		if not self:IsAlive() or self:InVehicle() or not provider:CanUse(self) then return end
		if car.bgnHeadingPending then
			timer.Simple(.1, function() if IsValid(car) and self:IsAlive() then self:EnterVehicle(car) end end)
			return
		end
		local npc = self:GetNPC()
		local saved = CaptureBody(self)
		local ok, model
		if not provider:GetDriver() then
			ok = provider:SetDriver(self)
			model = provider:GetVehicleAI()
		else
			ok, model = provider:AddPassenger(self)
		end
		if not ok or not IsValid(model) then return end

		bgNPC.Animator.Stop(npc)
		self.is_animated, self.anim_action, self.next_anim = false, nil, nil
		self.vehicle_body, self.vehicle, self.eternal = saved, provider, true
		self.model, self.skin, self.bodygroups, self.model_scale = saved.model, saved.skin, saved.bodygroups, saved.scale
		self.walkUpdatePathDelay = 0
		model:SetMaxHealth(saved.max_health)
		model:SetHealth(saved.health)
		model:SetNW2Bool('bgn_vehicle_entered', true)
		-- DV already has an anim entity for the occupant. No hidden NPC/NextBot survives boarding.
		bgNPC.Actors.Rebind(self, model)
		npc:Remove()
		hook.Run('BGN_OnEnterVehicle', self, provider)
	end)
end

local function IsExitOccupied(pos, saved, model)
	local mins, maxs = pos + saved.mins, pos + saved.maxs
	-- Non-colliding actors and newly spawned bodies may be missed by the engine trace.
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local npc = actor:GetNPC()
		if npc ~= model and IsValid(npc) and not actor:InVehicle() then
			local other_mins, other_maxs = npc:GetCollisionBounds()
			other_mins, other_maxs = npc:GetPos() + other_mins, npc:GetPos() + other_maxs
			if mins.x < other_maxs.x and maxs.x > other_mins.x
				and mins.y < other_maxs.y and maxs.y > other_mins.y
				and mins.z < other_maxs.z and maxs.z > other_mins.z then return true end
		end
	end
	return false
end

local function FindVehicleExitPos(vehicle, saved, model)
	local mins, maxs = vehicle:GetModelBounds()
	local pos = vehicle:GetPos()
	local forward = model.GetVehicleForward and model:GetVehicleForward() or vehicle:GetForward()
	local right = forward:Cross(vehicle:GetUp()):GetNormalized()
	local seat = model:GetNWEntity('Seat')
	local seat_pos = IsValid(seat) and seat:GetPos() or model:GetPos()
	if seat == vehicle then
		local eyes = vehicle:GetAttachment(vehicle:LookupAttachment('vehicle_driver_eyes'))
		if eyes then seat_pos = eyes.Pos end
	end
	local offset = seat_pos - pos
	local preferred_side = offset:Dot(right) > 0 and 1 or -1
	local left_edge, right_edge = math.huge, -math.huge
	for _, x in ipairs({ mins.x, maxs.x }) do
		for _, y in ipairs({ mins.y, maxs.y }) do
			local edge = (vehicle:LocalToWorld(Vector(x, y, 0)) - pos):Dot(right)
			left_edge, right_edge = math.min(left_edge, edge), math.max(right_edge, edge)
		end
	end
	local clearance = math.max(math.abs(saved.mins.x), math.abs(saved.mins.y), saved.maxs.x, saved.maxs.y) + 16
	local candidates = {}
	for _, name in ipairs(vehicle.Exitpoints or {}) do
		local attachment = vehicle:GetAttachment(vehicle:LookupAttachment(name))
		if attachment then candidates[#candidates + 1] = attachment.Pos end
	end
	table.sort(candidates, function(a, b) return a:DistToSqr(seat_pos) < b:DistToSqr(seat_pos) end)
	for _, side in ipairs({ preferred_side, -preferred_side }) do
		for _, shift in ipairs({ 0, -80, 80, 160 }) do
			local edge = side == 1 and right_edge + clearance or left_edge - clearance
			candidates[#candidates + 1] = pos + right * edge + forward * (offset:Dot(forward) + shift)
		end
	end
	for _, candidate in ipairs(candidates) do
		candidate = candidate + Vector(0, 0, 80)
		local ground = util.TraceLine({ start = candidate, endpos = candidate - Vector(0, 0, 500), filter = { model, vehicle } })
		-- A free floor below a bridge is not an exit beside the car.
		-- shortcut: the height bound assumes car-sized chassis; measure underbody ground height for tall vehicles.
		if ground.Hit and not ground.StartSolid and ground.HitNormal.z > .6 and math.abs(ground.HitPos.z - pos.z) <= 96 then
			candidate = ground.HitPos + Vector(0, 0, 2)
			local hull = util.TraceHull({ start = candidate, endpos = candidate, mins = saved.mins, maxs = saved.maxs,
				filter = model, mask = MASK_NPCSOLID })
			if util.IsInWorld(candidate) and not hull.StartSolid and not hull.Hit
				and not IsExitOccupied(candidate, saved, model) then return candidate end
		end
	end
end

-- A pursued target driving off: police stay seated until its car has stood still for a while or it gets out.
local STILL_TIME = 6
local function DrivesAway(target)
	local car = target:IsPlayer() and target:GetVehicle()
	if not car then
		local target_actor = bgNPC.Actors.Get(target)
		car = target_actor and target_actor:GetVehicle()
	end
	if not IsValid(car) then return false end
	if IsValid(car:GetParent()) then car = car:GetParent() end
	local now = CurTime()
	if car:GetVelocity():LengthSqr() > 50 ^ 2 then
		car.bgn_still_since = nil
	elseif not car.bgn_still_since or now - (car.bgn_still_seen or 0) > 2 then
		car.bgn_still_since = now
	end
	car.bgn_still_seen = now
	return not car.bgn_still_since or now - car.bgn_still_since < STILL_TIME
end

function Actor:ShouldExitVehicle()
	if not self:HasTeam('police') or not self.vehicle or not self.vehicle:IsValid() then return true end
	local vehicle = self.vehicle:GetVehicle()
	local max_health = vehicle:GetMaxHealth()
	local health = vehicle.GetCurHealth and vehicle:GetCurHealth() or vehicle:Health()
	if max_health > 0 and health <= max_health * 0.2 then return true end
	for _, enemy in ipairs(self.enemies) do
		if IsValid(enemy) and enemy:Health() > 0 and enemy:GetPos():DistToSqr(vehicle:GetPos()) <= 800 ^ 2
			and not DrivesAway(enemy) then return true end
	end
	if self:HasState('arrest') then
		for _, target in ipairs(self.targets) do
			if IsValid(target) and target:Health() > 0 and target:GetPos():DistToSqr(vehicle:GetPos()) <= 800 ^ 2
				and not DrivesAway(target) then return true end
		end
	end
	return false
end

function Actor:ExitVehicle(forced)
	local provider, saved = self.vehicle, self.vehicle_body
	if not provider or not saved then return false end
	if not provider:IsValid() or provider.removing then self:Remove() return false end
	if not forced and not self:ShouldExitVehicle() then return false end
	local old = self:GetNPC()
	saved.health = self:Health()
	local pos = FindVehicleExitPos(provider:GetVehicle(), saved, old)
	if not pos then return false end -- Keep the seat when every exit is obstructed.
	local npc = ents.Create(saved.class)
	if not IsValid(npc) then return false end
	for key, value in pairs(saved.keyvalues) do
		if key ~= 'origin' and key ~= 'angles' then npc:SetKeyValue(key, tostring(value)) end
	end
	npc.bgn_npc_class = saved.npc_class
	npc:SetModel(saved.model)
	npc:SetPos(pos)
	npc:SetAngles(Angle(0, provider:GetVehicle():GetAngles().y, 0))
	npc:Spawn()
	npc:Activate()
	if not IsValid(npc) then return false end
	npc:SetModel(saved.model)
	npc:SetSkin(saved.skin)
	npc:SetModelScale(saved.scale, 0)
	npc:SetColor(saved.color)
	npc:SetMaterial(saved.material)
	for id, value in pairs(saved.bodygroups) do npc:SetBodygroup(id, value) end
	npc:SetCollisionGroup(saved.collision_group)
	npc:SetMaxHealth(saved.max_health)
	npc:SetHealth(saved.health)
	if saved.proficiency and npc.SetCurrentWeaponProficiency then npc:SetCurrentWeaponProficiency(saved.proficiency) end
	self.vehicle, self.vehicle_body, self.eternal = nil, nil, saved.eternal
	bgNPC.Actors.Rebind(self, npc)
	self:CreateFakePlayerMethodsForNPC()
	for _, weapon in ipairs(saved.weapons) do
		local restored = self.body:GiveWeapon(weapon.class)
		if IsValid(restored) then restored:SetClip1(weapon.clip1) restored:SetClip2(weapon.clip2) end
	end
	if saved.active_weapon and npc.SelectWeapon then npc:SelectWeapon(saved.active_weapon) end
	if saved.bot_clip then npc.clip = saved.bot_clip end
	-- The new body knows nobody: restore the hostility the seated actor had.
	local fear = self:HasState('fear')
	for _, enemy in ipairs(self.enemies) do
		if IsValid(enemy) then self.body:SetDisposition(enemy, fear and D_FR or D_HT) end
	end
	local enemy = self:GetNearEnemy()
	if IsValid(enemy) then
		self.body:SetAlertLevel(fear and 'alert' or 'combat')
		self.body:SetEnemy(enemy)
	end
	if provider.driver == self then provider:SetDriver(nil) else provider:RemovePassenger(self) end
	self.last_vehicle, self.vehicle_data = provider, {}
	self.walkUpdatePathDelay, self.waitUpdateMovementDelay, self.next_lod, self.next_brain = 0, 0, 0, 0
	self.__last_player_interaction = CurTime()
	hook.Run('BGN_OnExitVehicle', self, provider)
	return true
end

-- Damage belongs to the stored character, never to the DV controller's health/lifetime.
function Actor:TakeVehicleDamage(amount, attacker, inflictor)
	local saved = self.vehicle_body
	if not saved or self.is_removed or amount <= 0 then return end
	attacker = bgNPC.Combat.ResolveVehicleAttacker(attacker) or attacker
	if bgNPC.Combat.IsAttacker(attacker)
		and attacker ~= self.npc and not bgNPC.Combat.IsIgnored(attacker) and not attacker.bgNPCIgnore then
		local damage = DamageInfo()
		damage:SetDamage(amount)
		damage:SetAttacker(attacker)
		damage:SetInflictor(IsValid(inflictor) and inflictor or attacker)
		if hook.Run('BGN_TakeDamageFromNPC', attacker, self.npc, damage) == true then return end
		amount = damage:GetDamage()
	end
	saved.health = math.max(0, self:Health() - amount)
	if IsValid(self.npc) then self.npc:SetHealth(saved.health) end
	if saved.health <= 0 then
		-- The seated DV entity cannot produce the character's death ragdoll.
		local ragdoll = ents.Create('prop_ragdoll')
		if IsValid(ragdoll) then
			local car = self:GetVehicle()
			ragdoll:SetKeyValue('spawnflags', '4100') -- Debris, retired by the engine's ragdoll limit.
			ragdoll:SetModel(saved.model)
			ragdoll:SetPos(IsValid(car) and (FindVehicleExitPos(car, saved, self.npc) or car:GetPos()) or self:GetPos())
			ragdoll:SetAngles(Angle(0, self:GetAngles().y, 0))
			ragdoll:SetSkin(saved.skin)
			ragdoll:SetModelScale(saved.scale, 0)
			ragdoll:SetColor(saved.color)
			ragdoll:SetMaterial(saved.material)
			for id, value in pairs(saved.bodygroups) do ragdoll:SetBodygroup(id, value) end
			ragdoll:Spawn()
			ragdoll:Activate()
		end
		if IsValid(ragdoll) then hook.Run('CreateEntityRagdoll', self.npc, ragdoll) end
		hook.Run('OnNPCKilled', self.npc, attacker, attacker)
		self:Remove()
	end
end

function Actor:InVehicle()
	if SERVER then
		return self.vehicle ~= nil and self.vehicle:IsValid()
	end
	return IsValid(self.npc) and self.npc:GetNW2Bool('bgn_vehicle_entered', false)
end

function Actor:GetVehicle()
	if not self.vehicle or not self:InVehicle() then return nil end
	return self.vehicle:GetVehicle()
end

function Actor:GetVehicleAI()
	if not self.vehicle or not self:InVehicle() then return nil end
	return self.vehicle:GetVehicleAI()
end
