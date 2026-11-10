--[[
	Medics: every actor death (not in a vehicle, not killed by the police) is a call. A free medic takes it, otherwise one is spawned
	near the body (bgNPC:FindSpawnPosition) with an ambulance when Decent Vehicle and the medic config have one.
	The ambulance drives to the body with the siren (npc_dvbgn_police, actor.drive_target_pos), the medic gets out,
	revives the actor (state "medic_revive") and drives away. A body can be revived for CORPSE_TIME seconds,
	and only while it exists: a removed server ragdoll or a client report of a removed client ragdoll closes the
	call (call.closed), and the medic goes back to its car.

	Medics come in pairs when the limit allows: the partner rides along, gets out with the medic, kneels at the
	body too and gets back in with it. No new ambulance is spawned when a player near the call already has one
	around (AMBULANCE_RADIUS); an empty one there is taken instead.
	Attacked by a player: the one reviving keeps reviving (saving a life comes first), the other one fights
	with fists (state "brawl"); below LOW_HEALTH a medic drops everything and runs, by car when there is one.
--]]

local Medics = {}
bgNPC.Medics = Medics

local CORPSE_TIME = 90
local EXIT_DIST_SQR = 700 ^ 2 -- the ambulance stops this close to the body
local VEHICLE_WAIT = 2 -- the medic enters the spawned ambulance after a short delay
local STOPPED_EXIT_TIME = 5 -- an ambulance standing this long gets out even far from the body
local STOPPED_SPEED = 50
local MEDIC_TYPE = 'medic'
local BODY_GONE_DIST_SQR = 200 ^ 2
local AMBULANCE_RADIUS = 3000
local LOW_HEALTH = 0.3
local PARTNER_PULL_DIST_SQR = 400 ^ 2 -- the partner this close gets in together, the car doesn't leave it behind
local REVIVE_OFFSETS = {
	Vector(0, 0, 8), Vector(40, 0, 8), Vector(-40, 0, 8), Vector(0, 40, 8), Vector(0, -40, 8),
	Vector(60, 60, 8), Vector(-60, -60, 8), Vector(60, -60, 8), Vector(-60, 60, 8),
}

local calls = {}
Medics.calls = calls

-- What the last hit was, to tell a death the medics can still fight for from one they cannot.
-- Only an explosion or a point-blank shot is always fatal; a vehicle hit is saved with the ordinary chance.
local POINT_BLANK_DIST_SQR = 150 ^ 2
local SHOT_DAMAGE = bit.bor(DMG_BULLET, DMG_BUCKSHOT)
hook.Add('EntityTakeDamage', 'BGN_Medics_LastDamage', function(target, dmginfo)
	if not (target:IsNPC() or target:IsNextBot()) then return end
	local attacker = dmginfo:GetAttacker()
	local damage_type = dmginfo:GetDamageType()
	target.bgn_last_damage_blast = bit.band(damage_type, DMG_BLAST) ~= 0
	target.bgn_last_damage_point_blank = bit.band(damage_type, SHOT_DAMAGE) ~= 0 and IsValid(attacker)
		and attacker:GetPos():DistToSqr(target:GetPos()) <= POINT_BLANK_DIST_SQR
end)

local function IsHopeless(npc)
	if npc.bgn_last_damage_blast or npc.bgn_last_damage_point_blank then return true end
	return math.random(100) <= GetConVar('bgn_medic_hopeless_chance'):GetInt()
end

-- @return boolean a medic is on the way to (or at) the body at pos and has not given the verdict yet
function Medics.IsHandling(pos)
	for _, call in ipairs(calls) do
		if call.medic and not call.verdict and not call.done and not call.closed
			and call.pos:DistToSqr(pos) < BODY_GONE_DIST_SQR then return true end
	end
	return false
end
local danger_areas = {}

function Medics.IsBlocked(pos)
	local now = CurTime()
	local radius = math.max(0, GetConVar('bgn_medic_danger_radius'):GetFloat())
	if GetConVar('bgn_medic_danger_time'):GetFloat() <= 0 then return false end
	for i = #danger_areas, 1, -1 do
		local area = danger_areas[i]
		if area.expires <= now or (area.attacker and (not IsValid(area.attacker) or area.attacker:Health() <= 0)) then
			table.remove(danger_areas, i)
		elseif area.pos:DistToSqr(pos) <= radius ^ 2 then
			return true
		end
	end
	return false
end

local function ClearDangerAreas(victim)
	for i = #danger_areas, 1, -1 do
		if danger_areas[i].attacker == victim then table.remove(danger_areas, i) end
	end
end

hook.Add('PlayerDeath', 'BGN_Medics_ClearDanger', ClearDangerAreas)
hook.Add('OnNPCKilled', 'BGN_Medics_ClearDanger', ClearDangerAreas)
hook.Add('BGN_OnValidSpawnActor', 'BGN_Medics_DangerArea', function(npc_type, _, _, pos)
	if npc_type == MEDIC_TYPE and Medics.IsBlocked(pos) then return true end
end)
hook.Add('PostCleanupMap', 'BGN_Medics_ClearCalls', function()
	table.Empty(danger_areas)
	table.Empty(calls)
end)

hook.Add('BGN_OnKilledActor', 'BGN_Medics_Call', function(actor, attacker)
	local npc = actor:GetNPC()
	ClearDangerAreas(npc)
	if actor:GetType() == MEDIC_TYPE and IsValid(npc) then
		local duration = GetConVar('bgn_medic_danger_time'):GetFloat()
		attacker = bgNPC.Combat.ResolveVehicleAttacker(attacker)
		if duration > 0 then
			danger_areas[#danger_areas + 1] = {
				pos = npc:GetPos(), expires = CurTime() + duration,
				attacker = IsValid(attacker) and attacker ~= npc and attacker:Health() > 0 and attacker or nil,
			}
		end
	end
	if not bgNPC.Config.IsTypeActive(MEDIC_TYPE) or actor:InVehicle() then return end
	local killer = IsValid(attacker) and bgNPC.Actors.Get(attacker)
	if killer and killer:HasTeam('police') then return end -- shot by the police: no ambulance
	if not IsValid(npc) then return end
	calls[#calls + 1] = {
		pos = npc:GetPos(),
		npc = npc,
		type = actor:GetType(),
		model = npc:GetModel(),
		skin = npc:GetSkin(),
		time = CurTime(),
		hopeless = IsHopeless(npc), -- the medic only declares it (state medic_revive), then the police take the body
	}
end)

-- A medic's enemies are only those who hurt it (not the wanted, not other people's fights).
local function Release(medic)
	medic.medic_call = nil
	medic.drive_target_pos = nil
	-- Respond marks the medic eternal even while it is fleeing or fighting; only medic_revive (and the car) resets it,
	-- so a medic that never got to it stayed immune to the remover and piled up over the limit
	if not medic:InVehicle() and not medic:HasState('medic_revive') then medic.eternal = false end
end

-- The medic reviving the body of a call (not its partner)
local function IsReviving(medic)
	local call = medic.medic_call
	return call ~= nil and call.medic == medic and not call.done and not call.closed
end

-- Below LOW_HEALTH: leaves the call and runs, by car when one of its own is near (go_to_police_car)
local function Flee(medic, attacker)
	local call = medic.medic_call
	if call then
		if call.medic == medic then
			-- the partner takes over, or another medic is found
			call.medic, call.partner = call.partner, nil
		elseif call.partner == medic then
			call.partner = nil
		end
	end
	Release(medic)
	medic:AddEnemy(attacker, 'fear')
	medic:SetState('go_to_police_car', { after_state = 'fear' }, true)
	if not medic:HasState('go_to_police_car') then medic:SetState('fear', nil, true) end
end

-- A medic's enemies are only those who hurt it (not the wanted, not other people's fights).
hook.Add('BGN_PreReactionTakeDamage', 'BGN_Medics_Attacker', function(attacker, target, _, dmginfo)
	local actor = bgNPC.Actors.Get(target)
	if not actor or actor:GetType() ~= MEDIC_TYPE then return end
	actor.medic_attackers = actor.medic_attackers or setmetatable({}, { __mode = 'k' })
	actor.medic_attackers[attacker] = true

	local health = actor:Health() - (dmginfo and dmginfo:GetDamage() or 0)
	if health < actor:GetMaxHealth() * LOW_HEALTH then Flee(actor, attacker) return false end

	-- fists against a player only (a brawl needs both sides; an armed actor is run from as usual)
	if not attacker:IsPlayer() then return end
	local partner = actor.medic_partner
	local fighter = actor
	if IsReviving(actor) then
		-- saving a life comes first: the partner fights, or nobody
		fighter = partner and partner:IsAlive() and not partner:InVehicle()
			and partner:Health() >= partner:GetMaxHealth() * LOW_HEALTH and partner or nil
	end
	if fighter and not fighter:HasState('brawl') then
		fighter:SetState('brawl', { enemy = attacker }, true)
	end
	return false
end)

hook.Add('BGN_AddActorEnemy', 'BGN_Medics_OnlyAttackers', function(actor, ent)
	if actor:GetType() == MEDIC_TYPE and not (actor.medic_attackers and actor.medic_attackers[ent]) then return true end
end)

-- npc_citizen picks its own model by citizentype on spawn; "unique" (4) keeps the medic model given before it.
hook.Add('BGN_PreSpawnActor', 'BGN_Medics_Model', function(npc, npc_type, data)
	if npc_type ~= MEDIC_TYPE or not istable(data.models) or #data.models == 0 then return end
	npc:SetKeyValue('citizentype', 4)
	npc:SetModel(data.models[math.random(#data.models)])
end)

-- A server-side ragdoll (ai_serverragdolls 1) is removed on revive.
hook.Add('CreateEntityRagdoll', 'BGN_Medics_Ragdoll', function(owner, ragdoll)
	for i = #calls, 1, -1 do
		if calls[i].npc == owner then calls[i].ragdoll = ragdoll return end
	end
end)

-- Clients own the usual NPC ragdolls: one tells when it fades or is cleaned up.
-- shortcut: any client may close a call near a position, harmless (the medic just leaves), rate-limited by Net
bgNPC.Net.Receive('bgn.medic_body_gone', function(_, pos)
	if not isvector(pos) then return end
	for _, call in ipairs(calls) do
		if not call.done and call.pos:DistToSqr(pos) < BODY_GONE_DIST_SQR then call.gone = true end
	end
end)

-- Brings the dead actor back: a new actor of the same type with the same look on the body's place,
-- or next to it when the place is taken (a car, another actor). The body stays when nowhere fits.
function Medics.Revive(call)
	if Medics.IsBlocked(call.pos) then return end
	if IsValid(call.ragdoll) then call.ragdoll:Remove() end
	local actor
	for _, offset in ipairs(REVIVE_OFFSETS) do
		actor = bgNPC:SpawnActor(call.type, call.pos + offset)
		if actor then break end
	end
	if not actor then return end
	bgNPC.Net.Send('bgn.body_remove', nil, call.pos) -- removes the client-side ragdoll
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	npc:SetModel(call.model)
	npc:SetSkin(call.skin or 0)
	npc:EmitSound('items/smallmedkit1.wav', 75)
	hook.Run('BGN_ActorRevived', actor, call)
end

local function IsFree(medic)
	return medic:IsAlive() and not medic.medic_call and not medic:EqualStateGroup('danger')
end

-- The medic and its partner (when free) take the call; the partner only assists
local function Assign(medic, call)
	call.medic = medic
	medic.medic_call = call
	local partner = medic.medic_partner
	if partner and IsFree(partner) then
		call.partner = partner
		partner.medic_call = call
	end
end

local function IsAmbulance(vehicle_provider)
	return string.Explode('|', vehicle_provider.type)[1] == 'medics'
end

-- @return Entity|nil an empty ambulance near pos to take
-- @return boolean an ambulance is already around a player who is near pos (no new one is spawned then)
local function AmbulancesNear(pos)
	local radius_sqr = AMBULANCE_RADIUS ^ 2
	local players = {}
	for _, ply in ipairs(player.GetAll()) do
		if ply:GetPos():DistToSqr(pos) < radius_sqr then players[#players + 1] = ply end
	end

	local empty, around
	for _, vehicle_provider in ipairs(bgNPC.DVCars or {}) do
		local car = vehicle_provider:GetVehicle()
		if IsValid(car) and IsAmbulance(vehicle_provider) then
			local car_pos = car:GetPos()
			if not vehicle_provider:GetDriver() and #vehicle_provider:GetPassengers() == 0
				and car_pos:DistToSqr(pos) < radius_sqr
			then
				empty = car
			end
			for _, ply in ipairs(players) do
				if car_pos:DistToSqr(ply:GetPos()) < radius_sqr then around = true break end
			end
		end
	end
	return empty, around
end

-- Gets both into the car once the driver is in (the driver's own EnterVehicle takes 0.5 s, SpawnVehicleWithActor more)
local function PartnerRidesAlong(medic, partner)
	timer.Simple(VEHICLE_WAIT - 0.5, function()
		if partner:IsAlive() and not partner:InVehicle() and medic:IsAlive() and medic:InVehicle() then
			partner:EnterVehicle(medic:GetVehicle())
		end
	end)
end

-- @return table|nil nearest free medic, or a new one (with a partner when the limit allows)
local function FindMedic(call)
	local best, best_dist
	for _, medic in ipairs(bgNPC.Actors.GetByType(MEDIC_TYPE)) do
		if IsFree(medic) then
			local dist = medic:GetPos():DistToSqr(call.pos)
			if not best or dist < best_dist then best, best_dist = medic, dist end
		end
	end
	if best then return best end

	local count, limit = #bgNPC.Actors.GetNPCsByType(MEDIC_TYPE), bgNPC.Config.GetTypeLimit(MEDIC_TYPE)
	if count >= limit then return end
	local pos = bgNPC:FindSpawnPosition({ position = call.pos })
	if not pos then return end
	local medic = bgNPC:SpawnActor(MEDIC_TYPE, pos, false, true)
	if not medic then return end

	local partner = count + 2 <= limit and bgNPC:SpawnActor(MEDIC_TYPE, pos + Vector(40, 0, 0), false, true) or nil
	if partner then
		medic.medic_partner, partner.medic_partner = partner, medic
	end

	local empty, around = AmbulancesNear(call.pos)
	local by_car = false
	if empty then
		medic:EnterVehicle(empty)
		by_car = true
	elseif not around then
		by_car = bgNPC:SpawnVehicleWithActor(medic, true)
	end
	if by_car then
		medic.medic_vehicle_wait = CurTime() + VEHICLE_WAIT
		if partner then PartnerRidesAlong(medic, partner) end
	end
	return medic
end

-- Moves the medic towards the body: drives while in the ambulance, walks and revives on foot.
local function Respond(medic, call)
	local now = CurTime()
	if (medic.medic_vehicle_wait or 0) > now then return end

	-- driving ignores the medic's fear: the car keeps going to the body
	if medic:InVehicle() then
		local vehicle = medic:GetVehicle()
		if IsValid(vehicle) and vehicle:GetPos():DistToSqr(call.pos) > EXIT_DIST_SQR then
			medic.drive_target_pos = call.pos
			if vehicle:GetVelocity():Length() > STOPPED_SPEED then
				medic.medic_stopped_since = nil
				return
			end
			-- stuck or the body is off the road: walk the rest
			medic.medic_stopped_since = medic.medic_stopped_since or now
			if now - medic.medic_stopped_since < STOPPED_EXIT_TIME then return end
		end
		medic.drive_target_pos = nil
		medic.medic_stopped_since = nil
		medic.medic_ambulance = vehicle
		medic:ExitVehicle()
	end

	-- the partner gets out too and goes along
	local partner = call.partner
	local helpers = { medic }
	if partner and partner:IsAlive() and partner.medic_call == call then
		if partner:InVehicle() then
			partner.medic_ambulance = partner:GetVehicle()
			partner:ExitVehicle()
		end
		helpers[2] = partner
	end

	for _, actor in ipairs(helpers) do
		actor.eternal = true -- on foot out of the players' sight the remover would take or teleport it
		-- in a fight or running: not now (a brawl ends by itself and the revive goes on)
		if not actor:EqualStateGroup('danger') and not actor:HasState('brawl') then
			-- forced: a medic still walking back from the previous call is in the same state
			local data = actor:HasState('medic_revive') and actor:GetStateData()
			if not data or data.call ~= call then actor:SetState('medic_revive', { call = call }, true) end
		end
	end
end

Medics.PARTNER_PULL_DIST_SQR = PARTNER_PULL_DIST_SQR

timer.Create('BGN_MedicsDispatch', 1, 0, function()
	local now = CurTime()
	for i = #calls, 1, -1 do
		local call = calls[i]
		local medic = call.medic
		local body_removed = call.ragdoll ~= nil and not IsValid(call.ragdoll)
		if call.done or call.gone or body_removed or call.time + CORPSE_TIME < now then
			call.closed = true
			table.remove(calls, i)
			if medic and medic.medic_call == call then Release(medic) end
			if call.partner and call.partner.medic_call == call then Release(call.partner) end
		elseif Medics.IsBlocked(call.pos) then
			for _, responder in pairs({ call.medic, call.partner }) do
				if responder:IsAlive() and responder.medic_call == call then
					Release(responder)
					responder:StopWalk()
					responder:GetBody():StopMoving()
				end
			end
			call.medic, call.partner = nil, nil
		elseif not medic or not medic:IsAlive() then
			medic = FindMedic(call)
			if medic then Assign(medic, call) end
		else
			Respond(medic, call)
		end
	end
end)
