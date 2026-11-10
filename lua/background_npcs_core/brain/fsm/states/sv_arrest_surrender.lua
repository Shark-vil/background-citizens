local ArrestModule = bgNPC.Modules.Get('player_arrest')

local BUSY_RADIUS_SQR = 2500 ^ 2

-- @return boolean true when there are officers around and every one of them fights someone else
-- (none arrests or hunts this actor): only then may the surrendered actor sneak away
local function PoliceBusyElsewhere(actor)
	local npc, found = actor:GetNPC(), false
	for _, police in ipairs(bgNPC.Actors.GetByTeam('police')) do
		local police_npc = police:GetNPC()
		if police:IsAlive() and IsValid(police_npc) and police_npc:GetPos():DistToSqr(npc:GetPos()) <= BUSY_RADIUS_SQR then
			if police:HasTarget(npc) or police:HasEnemy(npc) or police:EnemiesCount() == 0 then return false end
			found = true
		end
	end
	return found
end

-- A surrender never turns back into a fight: the officers stop being enemies, then the actor
-- either slips away (the police are busy with someone else) or just calms down.
local function EndSurrender(actor, target)
	actor:RemoveTarget(target)
	for _, police in ipairs(bgNPC.Actors.GetByTeam('police')) do
		actor:RemoveEnemy(police:GetNPC())
	end
	if PoliceBusyElsewhere(actor) then
		actor:SetState('retreat', nil, true)
	else
		actor:RandomState()
	end
end

bgNPC.States.Register('arrest_surrender', 'danger', {
	pre_start = function(actor)
		local npc = actor:GetNPC()
		if IsValid(npc) and not ArrestModule:HasTarget(npc) then
			local target = actor:GetFirstTarget()
			if IsValid(target) then
				actor:GetBody():SetDisposition(target, D_FR)
				actor:AddEnemy(target)
				actor:RemoveTarget(target)
			end
			return 'retreat'
		end
	end,
	start = function(actor, state, data)
		data.check_target_time = CurTime() + 2
		data.arrest_limit_time = CurTime() + 30

		for _, police in ipairs(bgNPC.Actors.GetAll()) do
			if police and police:IsAlive() and police:HasTeam('police') then
				police:RemoveEnemy(actor.npc)
			end
		end
	end,
	update = function(actor, state, data)
		if actor:HasNoTargets() then
			actor:RandomState()
			return
		end

		if not actor:IsAnimationPlayed() then
			actor:PlayStaticSequence('Fear_Reaction', true)
		end

		local target = actor:GetFirstTarget()
		if not IsValid(target) then
			actor:RemoveTarget(target)
		elseif actor:CheckMoveUpdate('state_arrest_surrender', 2) then -- false between checks: the target stays
			local TargetActor = bgNPC.Actors.Get(target)
			if not TargetActor or not TargetActor:HasState('arrest') or data.arrest_limit_time < CurTime() then
				EndSurrender(actor, target)
			end
		end
	end
})