hook.Add("BGN_SetNPCState", "BGN_PlaySoundForFearState", function(actor, state)
	if state ~= 'fear' or not actor:IsAlive() then return end
	if math.random(0, 10) > 5 then return end
	
	local target = actor:GetNearTarget()
	if not IsValid(target) then return end

	local npc = actor:GetNPC()
	if target:GetPos():DistToSqr(npc:GetPos()) > 490000 then return end
	
	actor:FearScream()
end)

bgNPC:SetStateAction('fear', function(actor)
	local target = actor:GetNearTarget()
	if not IsValid(target) or target:Health() <= 0 then return end

	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0
	data.reset_fear = data.reset_fear or CurTime() + 30
	data.call_for_help = data.call_for_help or CurTime() + math.random(25, 40)

	local isViewTarget = bgNPC:IsTargetRay(npc, target)
	if isViewTarget then
		data.reset_fear = CurTime() + 30
	end

	local dist = npc:GetPos():DistToSqr(target:GetPos())
	if (not isViewTarget and dist >= 1000000) or data.reset_fear < CurTime() then -- 1000 ^ 2
		actor:RemoveTarget(target)
		data.reset_fear = CurTime() + 30
	elseif npc:Disposition(target) ~= D_FR then
		npc:AddEntityRelationship(target, D_FR, 99)
	end

	if npc:GetTarget() ~= target then
		npc:SetTarget(target)
	end

	if data.delay < CurTime() then
		if math.random(0, 100) == 0 and dist > 90000 and not bgNPC:NPCIsViewVector(target, npc:GetPos(), 70) then
			actor:SetState('calling_police', {
				delay = 0
			})
			return
		end

		if data.schedule == 'run' and dist > 360000 and math.random(0, 10) == 0 then
			data.schedule = 'dyspnea'
			actor:ResetSequence()
			actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02_Entry', false, nil, function()
				actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02', true, math.random(5, 15), function()
					data.schedule = 'run'
				end)
			end)
			data.delay = CurTime() + 7
		elseif data.schedule ~= 'dyspnea' then
			if math.random(0, 10) <= 1 then
				data.schedule = 'fear'
			else
				data.schedule = 'run'
				data.update_run = 0
			end

			data.delay = CurTime() + 10
		end
	end

	if dist < 22500 then -- 150 ^ 2
		data.schedule = 'fear'
		data.call_for_help = CurTime() + math.random(25, 40)
		data.reset_fear = CurTime() + 30
		if math.random(0, 100) <= 2 then
			actor:CallForHelp(target)
		end
	elseif dist > 360000 then -- 600 ^ 2
		if data.call_for_help < CurTime() then
			actor:CallForHelp(target)
			data.call_for_help = CurTime() + math.random(25, 40)
		else
			if data.schedule == 'run' and data.update_run < CurTime() then
				local pos = actor:GetDistantPointToPoint(target:GetPos(), 2000)
				if pos ~= nil then
					actor:WalkToPos(pos, 'run')
				end
				data.update_run = CurTime() + math.random(10, 20)
			end
		end
	end
end)

timer.Create('BGN_Timer_FearStateAnimationController', 0.3, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('fear')) do
		if not actor:IsAlive() then goto skip end

		local target = actor:GetNearTarget()
		if not IsValid(target) then goto skip end

		local data = actor:GetStateData()
		data.anim = data.anim or 0

		if data.schedule == 'fear' then                        
			local is_idle = math.random(0, 100)
			
			data.update_anim = data.update_anim or 0
			if data.update_anim < CurTime() then
				data.update_anim = CurTime() + 2
				data.anim = math.random(0, 100)
			end

			if data.anim > 30 then
				if is_idle >= 10 then
					actor:PlayStaticSequence('Fear_Reaction_Idle', true)
				else
					actor:PlayStaticSequence('Fear_Reaction', true)
				end
			else
				if is_idle >= 10 then
					actor:PlayStaticSequence('cower_Idle', true)
				else
					actor:PlayStaticSequence('cower', true)
				end
			end

			actor:WalkToPos(nil)
		end

		::skip::
	end
end)

hook.Add('BGN_PostReactionTakeDamage', 'BGN_UpdateResetFearTimer', function(attacker, target, dmginfo)
	for _, actor in ipairs(bgNPC:GetAllByRadius(attacker:GetPos(), 1000)) do
		if actor:HasState('fear') and bgNPC:IsTargetRay(actor:GetNPC(), attacker) then
			local data = actor:GetStateData()
			data.reset_fear = CurTime() + 30
		end
	end
end)