local ASSET = {}
local arrest_targets = {}

function ASSET:AddTarget(target, policeActor)
	if not IsValid(target) or (not target:IsPlayer() and not target:IsNPC()) then return false end
	if not policeActor or arrest_targets[target] then return false end

	local ArrestComponent = {
		warningTime = CurTime() + GetConVar('bgn_arrest_time_limit'):GetFloat(),
		notify_order_time = 0,
		notify_arrest_time = 0,
		arrest_time = 0,
		detention = false,
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
	ArrestComponent.arrested = true
	ArrestComponent.damege_count = 1
end

function ASSET:FoundPoliceInRadius(target, radius)
	radius = radius or 700
	local policeActor

	for _, actor in ipairs(bgNPC:GetAllByRadius(target:GetPos(), 700)) do
		if actor:IsAlive()
			and actor:HasTeam('police')
			and actor:GetNPC():slibIsTraceEntity(target, 700)
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