--[[
	pick_up_weapon: an unarmed actor in danger (fear / run_from_danger) runs to a dropped weapon nearby,
	takes it and fights. It was spawned without a weapon, so it shoots like a novice (actor.novice_shooter,
	see bgNPC.Combat.ApplyWeaponSkill). Dropped weapons: HL2 NPCs drop theirs by the engine, NextBots on death.
--]]

local SCAN_PERIOD = 1
local SEARCH_RADIUS = 500
local REACH_DIST_SQR = 60 ^ 2
local GIVE_UP_TIME = 8
local SCAN_STATES = { fear = true, run_from_danger = true }
local NOT_WEAPONS = { weapon_physgun = true, weapon_physcannon = true, gmod_tool = true, gmod_camera = true }

local function IsFreeWeapon(ent)
	return ent:IsWeapon() and not NOT_WEAPONS[ent:GetClass()] and not ent.bgn_nextbot_weapon
		and not IsValid(ent:GetOwner()) and not IsValid(ent:GetParent())
end

-- @return entity|nil nearest free weapon nobody else is going for
local function FindWeapon(pos)
	local now = CurTime()
	local best, best_dist
	for _, ent in ipairs(ents.FindInSphere(pos, SEARCH_RADIUS)) do
		if IsFreeWeapon(ent) and (ent.bgn_reserved_until or 0) < now then
			local dist = pos:DistToSqr(ent:GetPos())
			if not best or dist < best_dist then best, best_dist = ent, dist end
		end
	end
	return best
end

local cvar_enabled = GetConVar('bgn_pick_up_weapons')

local function CanArm(actor)
	if not cvar_enabled:GetBool() or actor.weapon or not actor:IsAlive() or actor:IsStayingOut() or actor:InVehicle() then return false end
	if not (actor:IsNPC() or actor:IsNextBot()) then return false end
	local cvar_disable_weapon = GetConVar('bgn_disable_weapon_' .. actor:GetType())
	return not (cvar_disable_weapon and cvar_disable_weapon:GetBool())
end

bgNPC.States.Register('pick_up_weapon', 'danger', {
	update = function(actor)
		local data = actor:GetStateData()
		local weapon = data.weapon
		if actor:HasNoEnemies() or not IsValid(weapon) or not IsFreeWeapon(weapon) or (data.give_up or 0) < CurTime() then
			actor:SetState('run_from_danger')
			return
		end

		if actor:GetPos():DistToSqr(weapon:GetPos()) > REACH_DIST_SQR then
			if (data.next_walk or 0) < CurTime() then
				data.next_walk = CurTime() + 1
				actor:WalkToPos(weapon:GetPos(), 'run')
			end
			return
		end

		local weapon_class = weapon:GetClass()
		weapon:Remove()
		actor.novice_shooter = true
		actor.weapon = weapon_class
		actor:SetState('defense') -- arms itself there (PrepareWeapon)
	end,
})

timer.Create('BGN_PickUpWeaponScan', SCAN_PERIOD, 0, function()
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		if SCAN_STATES[actor:GetState()] and CanArm(actor) then
			local weapon = FindWeapon(actor:GetPos())
			local give_up = CurTime() + GIVE_UP_TIME
			if weapon and actor:SetState('pick_up_weapon', { weapon = weapon, give_up = give_up }) then
				weapon.bgn_reserved_until = give_up
			end
		end
	end
end)
