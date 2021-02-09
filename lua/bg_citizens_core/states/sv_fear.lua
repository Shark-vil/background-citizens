local male_scream = {
	'ambient/voices/m_scream1.wav',
	'vo/coast/bugbait/sandy_help.wav',
	'vo/npc/male01/help01.wav',
	'vo/Streetwar/sniper/male01/c17_09_help01.wav',
	'vo/Streetwar/sniper/male01/c17_09_help02.wav',
	'vo/npc/male01/no01.wav',
	'vo/npc/male01/no02.wav',
}

local female_scream = {
	'ambient/voices/f_scream1.wav',
	'vo/canals/arrest_helpme.wav',
	'vo/npc/female01/help01.wav',
	'vo/npc/female01/help01.wav',
	'vo/npc/female01/no01.wav',
	'vo/npc/female01/no02.wav',
}

local function FearScream(npc)
	local npc_model = npc:GetModel()
	local scream_sound = nil
	if tobool(string.find(npc_model, 'female_*')) then
		scream_sound = table.Random(female_scream)
	elseif tobool(string.find(npc_model, 'male_*')) then
		scream_sound = table.Random(male_scream)
	else
		scream_sound = table.Random(table.Inherit(male_scream, female_scream))
	end

	npc:EmitSound(scream_sound, 450, 100, 1, CHAN_AUTO)
end

local function CallForHelp(actor, npc, target)
	FearScream(npc)
				
	local near_actors = bgNPC:GetAllByRadius(npc:GetPos(), 1000)
	for _, NearActor in ipairs(near_actors) do
		local npc = NearActor:GetNPC()
		if NearActor:IsAlive() and NearActor:HasTeam(actor) and bgNPC:IsTargetRay(npc, target) then
			NearActor:SetState(NearActor:GetReactionForProtect())
			NearActor:AddTarget(target)
		end
	end
end

hook.Add("BGN_SetNPCState", "BGN_PlaySoundForFearState", function(actor, state)
	if state ~= 'fear' or not actor:IsAlive() then return end
	if math.random(0, 10) > 4 then return end
	
	local target = actor:GetNearTarget()
	if not IsValid(target) then return end

	local npc = actor:GetNPC()
	if target:GetPos():DistToSqr(npc:GetPos()) > 490000 then return end
	
	FearScream(npc)
end)

timer.Create('BGN_Timer_FearStateController', 1, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('fear')) do
		if not actor:IsAlive() then goto skip end

		local target = actor:GetNearTarget()
		if not IsValid(target) then goto skip end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0
		data.reset_fear = data.reset_fear or CurTime() + 30
		data.call_for_help = data.call_for_help or CurTime() + math.random(25, 40)

		local dist = npc:GetPos():DistToSqr(target:GetPos())
		if dist >= 1000000 or (data.reset_fear < CurTime() 
			and not bgNPC:IsTargetRay(npc, target))
		then -- 1000 ^ 2
			actor:RemoveTarget(target)
			data.reset_fear = CurTime() + 30
		elseif npc:Disposition(target) ~= D_FR then
			npc:AddEntityRelationship(target, D_FR, 99)
		end

		if npc:GetTarget() ~= target then
			npc:SetTarget(target)
		end

		if data.delay < CurTime() then
			if math.random(0, 100) == 0 and dist > 90000 
				and not bgNPC:NPCIsViewVector(target, npc:GetPos(), 70) 
			then
				actor:SetState('calling_police', {
					delay = 0
				})
				goto skip
			end

			if data.schedule == 'run' and dist > 360000 -- 600 ^ 2 
				and math.random(0, 10) == 0
			then
				data.schedule = 'dyspnea'

				actor:ResetSequence()

				data.sequence = 'd2_coast03_PostBattle_Idle02_Entry'
				if not actor:IsValidSequence(data.sequence) then
					data.sequence = 'corpse_idle_to_inspect'
				end

				data.delay = CurTime() + 7
			else
				if data.schedule == 'dyspnea' then
					if actor:HasSequence('corpse_inspect_idle') then
						actor:PlayStaticSequence('corpse_inspect_to_idle')
					end
					data.schedule = 'dyspnea_to_idle'
				end

				if data.schedule == 'dyspnea_to_idle' then
					if not actor:IsSequenceFinished() then
						goto skip
					end
				end

				actor:ResetSequence()

				if math.random(0, 10) <= 1 then
					data.schedule = 'fear'
				else
					data.schedule = 'run'
					data.update_run = 0
				end

				data.delay = CurTime() + 10
			end

			actor:ClearSchedule()
		end

		if dist < 22500 then -- 150 ^ 2
			data.schedule = 'fear'
			data.call_for_help = CurTime() + math.random(25, 40)
			data.reset_fear = CurTime() + 30
			if math.random(0, 100) <= 2 then
				CallForHelp(actor, npc, target)
			end
		elseif dist > 360000 then -- 600 ^ 2
			if data.call_for_help < CurTime() then
				CallForHelp(actor, npc, target)
				data.call_for_help = CurTime() + math.random(25, 40)
			end
		end

		::skip::
	end
end)

timer.Create('BGN_Timer_FearStateAnimationController', 0.3, 0, function()
	for _, actor in ipairs(bgNPC:GetAllByState('fear')) do
		if not actor:IsAlive() then goto skip end

		local target = actor:GetNearTarget()
		if not IsValid(target) then goto skip end

		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.anim = data.anim or 0

		if data.schedule == 'dyspnea' then
			if data.sequence == 'corpse_idle_to_inspect' then
				if not actor:HasSequence(data.sequence) then
					actor:SetNextSequence('corpse_inspect_idle', true, 0, function(a)
						data.sequence = 'corpse_inspect_idle'
					end)
					actor:PlayStaticSequence(data.sequence)
				end
			elseif data.sequence == 'd2_coast03_PostBattle_Idle02_Entry' then
				if not actor:HasSequence(data.sequence) then
					actor:SetNextSequence('d2_coast03_PostBattle_Idle02', true, 0, function(a)
						data.sequence = 'd2_coast03_PostBattle_Idle02'
					end)
					actor:PlayStaticSequence(data.sequence)
				end
			end
		elseif data.schedule == 'fear' then                        
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
		elseif data.schedule == 'run' and data.update_run < CurTime() then
			if data.old_pos ~= nil and data.old_pos:DistToSqr(npc:GetPos()) <= 900 then
				data.old_pos = nil
				data.schedule = 'fear'
				goto skip
			end

			data.old_pos = npc:GetPos()

			if math.random(0, 10) > 5 then
				npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
			else               
				local pos = actor:GetDistantPointInRadius(target:GetPos(), 1500)
				local move_pos = actor:GetClosestPointToPosition(pos)

				if move_pos == nil then
					npc:SetSchedule(SCHED_RUN_FROM_ENEMY)
				else
					npc:SetSaveValue("m_vecLastPosition", move_pos)
					npc:SetSchedule(SCHED_FORCED_GO_RUN)
				end
			end
			
			data.update_run = CurTime() + 3
		end

		::skip::
	end
end)

hook.Add('BGN_PostReactionTakeDamage', 'BGN_UpdateResetFearTimer', function(attacker, target, dmginfo)
	for _, actor in ipairs(bgNPC:GetAllByRadius(attacker:GetPos(), 1000)) do
		if actor:IsAlive() and actor:HasState('fear') and bgNPC:IsTargetRay(actor:GetNPC(), attacker) then
			actor:GetStateData().reset_fear = CurTime() + 30
		end
	end
end)