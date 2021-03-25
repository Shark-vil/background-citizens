hook.Add("BGN_SetNPCState", "BGN_PlaySoundForFearState", function(actor, state)
	if state ~= 'fear' or not actor:IsAlive() then return end
	if math.random(0, 10) > 5 then return end
	
	local enemy = actor:GetEnemy()
	if not IsValid(enemy) then return end

	local npc = actor:GetNPC()
	if enemy:GetPos():DistToSqr(npc:GetPos()) > 490000 then return end
	
	actor:WalkToPos(nil)
	actor:FearScream()
end)

bgNPC:SetStateAction('fear', function(actor)
	local enemy = actor:GetNearEnemy()
	if not IsValid(enemy) or enemy:Health() <= 0 then return end

	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0
	data.call_for_help = data.call_for_help or CurTime() + math.random(25, 40)
	data.update_run = data.update_run or 0

	local dist = npc:GetPos():DistToSqr(enemy:GetPos())
	if data.delay < CurTime() then
		if math.random(0, 100) == 0 and dist > 90000 and not bgNPC:NPCIsViewVector(enemy, npc:GetPos(), 70) then
			actor:SetState('calling_police', {
				delay = 0
			})
			return
		end

		if data.schedule == 'run' and dist > 360000 and math.random(0, 10) == 0 then
			data.schedule = 'dyspnea'
			actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02_Entry', false, nil, function()
				actor:PlayStaticSequence('d2_coast03_PostBattle_Idle02', true, math.random(5, 15), function()
					data.schedule = 'run'
				end)
			end)
			data.delay = CurTime() + 7
		elseif data.schedule ~= 'dyspnea' then
			data.delay = CurTime() + 10
		end
	end

	if dist < 40000 then -- 200 ^ 2
		data.schedule = 'fear'
		data.call_for_help = CurTime() + math.random(25, 40)
		data.reset_fear = CurTime() + 30
		
		if math.random(0, 100) <= 2 then
			actor:CallForHelp(enemy)
		end

		if actor:HasSequence('d2_coast03_PostBattle_Idle02') then
			actor:ResetSequence()
		end
	else
		data.schedule = 'run'

		if actor:IsAnimationPlayed() then
			actor:ResetSequence()
		end

		if data.update_run < CurTime() then
			local position = actor:GetDistantPointToPoint(enemy:GetPos(), math.random(700, 1500))
			if position then
				actor:WalkToPos(position, 'run')
				data.update_run = CurTime() + math.random(10, 15)
			end
		end

		if dist > 360000 then -- 600 ^ 2
			if data.call_for_help < CurTime() then
				actor:CallForHelp(enemy)
				data.call_for_help = CurTime() + math.random(20, 30)
			end
		end
	end
end)

timer.Create('BGN_Timer_FearStateAnimationController', 0.3, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('fear')) do
		if not actor:IsAlive() then goto skip end

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