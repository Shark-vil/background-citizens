local ASSET = {}
local arrest_targets = {}

function ASSET:AddTarget(target, policeActor)
	if not IsValid(target) or (not target:IsPlayer() and not target:IsNPC() and not target:IsNextBot()) then return false end
	if not policeActor or arrest_targets[target] then return false end

	local ArrestComponent = {
		warningTime = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
		notify_order_time = 0,
		notify_arrest_time = 0,
		arrest_time = 0,
		detention = false,
		holders = {}, -- police actors that hold the target in detention now (several officers share one component)
		arrested = true,
		damege_count = 1,
		is_look_police = false,
		policeActor = policeActor,
	}

	arrest_targets[target] = ArrestComponent
	return true
end

function ASSET:UpdateArrest(target)
	local ArrestComponent = self:GetTarget(target)
	if not ArrestComponent then return end

	ArrestComponent.warningTime = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat()
	ArrestComponent.notify_order_time = 0
	ArrestComponent.notify_arrest_time = 0
	ArrestComponent.arrest_time = 0
	ArrestComponent.detention = false
	ArrestComponent.holders = {}
	ArrestComponent.arrested = true
	ArrestComponent.damege_count = 1
end

function ASSET:FoundPoliceInRadius(target, radius)
	radius = radius or 700
	local policeActor

	for _, actor in ipairs(bgNPC.Actors.GetInRadius(target:GetPos(), 700)) do
		if actor:IsAlive()
			and actor:HasTeam('police')
			and bgNPC.Util.CanSeeEntity(actor:GetNPC(), target)
		then
			if not policeActor then
				policeActor = actor
			else
				local TargetPos = target:GetPos()
				local NewActorPos = actor:GetNPC():GetPos()
				local OldActorPos = policeActor:GetNPC():GetPos()

				if NewActorPos:DistToSqr(TargetPos) < OldActorPos:DistToSqr(TargetPos) then
					policeActor = actor
				end
			end
		end
	end

	return policeActor
end

function ASSET:UpdatePolice(target)
	local ArrestComponent = self:GetTarget(target)
	if not ArrestComponent then return end

	local policeActor = ArrestComponent.policeActor
	if policeActor and policeActor:IsAlive() then return end

	ArrestComponent.policeActor = self:FoundPoliceInRadius(target)
end

function ASSET:RemoveTarget(target)
	local ArrestComponent = self:GetTarget(target)
	if not ArrestComponent then return end

	if ArrestComponent.policeActor then
		ArrestComponent.policeActor:RemoveTarget(target)
	end

	arrest_targets[target] = nil
end

function ASSET:ClearAll()
	arrest_targets = {}
end

function ASSET:HasTarget(target)
	if IsValid(target) and arrest_targets[target] then return true end
	return false
end

function ASSET:GetTarget(target)
	if not IsValid(target) then return end
	return arrest_targets[target]
end

function ASSET:GetAllTargets()
	return arrest_targets
end

-- The police still try to arrest: arrest mode is on, the target didn't kill (arrested), didn't keep attacking
-- (damege_count), obeys within the time limit and is not wanted.
-- @return boolean
function ASSET:CanArrest(target)
	local ArrestComponent = self:GetTarget(target)
	if not ArrestComponent or not ArrestComponent.arrested or ArrestComponent.damege_count > 5 then return false end
	if not GetConVar('bgn_arrest_mode'):GetBool() then return false end
	if not target:IsPlayer() then return true end
	if not ArrestComponent.detention and ArrestComponent.warningTime < CurTime() then return false end
	-- a second chance (sv_surrender.lua) holds even while wanted, until the player attacks again
	if ArrestComponent.surrender then return (target.bgn_last_attack or 0) < ArrestComponent.surrender end
	return not bgNPC.Modules.Get('wanted'):HasWanted(target)
end

-- A valid arrest needs an officer actually handling it; an NPC must also have surrendered.
function ASSET:IsProtected(target)
	if not self:CanArrest(target) then return false end
	local suspect = bgNPC.Actors.Get(target)
	if suspect and not suspect:HasState('arrest_surrender') then return false end
	local component = self:GetTarget(target)
	for officer in pairs(component.officers or {}) do
		if officer:IsAlive() and officer:HasState('arrest') and officer:HasTarget(target) then return true end
	end
	return false
end

local function IsLawAlly(actor)
	return actor:HasTeam('residents') or actor:HasTeam('police')
end

hook.Add('BGN_SetState', 'BGN_ArrestCeaseFire', function(police, state)
	if state ~= 'arrest' or not police:HasTeam('police') then return end
	local target = police:GetFirstTarget()
	local component = ASSET:GetTarget(target)
	if not component then return end
	component.officers = component.officers or {}
	component.officers[police] = true
	if not ASSET:IsProtected(target) then return end

	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		if actor:IsAlive() and actor:GetNPC() ~= target and IsLawAlly(actor) then
			local body = actor:GetBody()
			local aiming = body and body:GetEnemy() == target
			local arresting = actor:HasState('arrest')
			local locked = actor:IsStateLock()
			-- Removing the last enemy normally randomizes the state; keep officers on their arrest.
			if arresting then actor:StateLock(true) end
			actor:RemoveEnemy(target)
			actor:StateLock(locked)
			if aiming then actor:ClearSchedule() end
		end
	end
end)

hook.Add('BGN_AddActorEnemy', 'BGN_ArrestCeaseFire', function(actor, enemy)
	if IsLawAlly(actor) and ASSET:IsProtected(enemy) then return true end
end)

hook.Add('EntityTakeDamage', 'BGN_ArrestCeaseFire', function(target, dmginfo)
	if not ASSET:IsProtected(target) then return end
	local attacker = bgNPC.Combat.ResolveVehicleAttacker(dmginfo:GetAttacker())
	local actor = bgNPC.Actors.Get(attacker)
	if actor and IsLawAlly(actor) then return true end
end)

function ASSET:NotSubjectToArrest(target)
	local ArrestComponent = self:GetTarget(target)
	if ArrestComponent then
		ArrestComponent.arrested = false

		local actor = ArrestComponent.policeActor
		if actor then
			actor:RemoveAllTargets()
			actor:AddEnemy(target)
			actor:SetState('defense')
		end
	end
end

hook.Add('PlayerDeath', 'BGN_ArrestModule_ClearDataOnPlayerDeath', function(victim, inflictor, attacker)
	ASSET:RemoveTarget(victim)
end)

hook.Add('BGN_RemoveWantedTarget', 'BGN_ArrestModule_ClearByWanted', function(target)
	ASSET:RemoveTarget(target)
end)

hook.Add('PostCleanupMap', 'BGN_ArrestModule_ClearPlayerOnCleanupMap', function()
	ASSET:ClearAll()
end)

list.Set('BGN_Modules', 'player_arrest', ASSET)
