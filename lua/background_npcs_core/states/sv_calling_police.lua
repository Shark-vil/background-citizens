local bgNPC = bgNPC
local table_RandomBySeq = table.RandomBySeq
local CurTime = CurTime
local IsValid = IsValid
local pairs = pairs
local hook_Run = hook.Run
local math_random = math.random
local CHAN_AUTO = CHAN_AUTO
--
local asset = bgNPC:GetModule('wanted')
local cvar_bgn_enable_wanted_mode = GetConVar('bgn_enable_wanted_mode')
local phone_911_sounnds = {
	Sound('background_npcs/calling_police/911/1.wav'),
	Sound('background_npcs/calling_police/911/2.wav'),
	Sound('background_npcs/calling_police/911/3.wav'),
	Sound('background_npcs/calling_police/911/4.wav'),
}
local phone_beep_sounnds = {
	Sound('background_npcs/calling_police/bepp/1.wav'),
	Sound('background_npcs/calling_police/bepp/2.wav'),
	Sound('background_npcs/calling_police/bepp/3.wav'),
	Sound('background_npcs/calling_police/bepp/4.wav'),
	Sound('background_npcs/calling_police/bepp/5.wav'),
	Sound('background_npcs/calling_police/bepp/6.wav'),
	Sound('background_npcs/calling_police/bepp/7.wav'),
	Sound('background_npcs/calling_police/bepp/8.wav'),
}

local function IsValidWantedMode()
	return cvar_bgn_enable_wanted_mode:GetBool()
end

bgNPC:SetStateAction('calling_police', 'danger', {
	pre_start = function(actor)
		if not IsValidWantedMode() then
			return 'fear'
		end
	end,
	stop = function(actor)
		actor:StopStaticSequence()
	end,
	update = function(actor)
		if actor:HasNoEnemies() then
			actor:RandomState()
			return
		end

		local currentEnemy = actor:GetEnemy()
		local reaction = actor:GetReactionForDamage()
		reaction = reaction == 'calling_police' and 'fear' or reaction

		if not IsValidWantedMode() or not IsValid(currentEnemy) or asset:HasWanted(currentEnemy) then
			actor:SetState(reaction)
			return
		end

		local enemyActor = bgNPC:GetActor(currentEnemy)
		if enemyActor and enemyActor:HasTeam('police') then
			actor:SetState(reaction)
			return
		end

		local npc = actor:GetNPC()
		local npc_index = npc:EntIndex()

		-- 90000 = 300 ^ 2
		if not bgNPC:IsTargetRay(npc, currentEnemy) or npc:GetPos():DistToSqr(currentEnemy:GetPos()) < 90000 then
			local rnd = math_random(0, 100)
			if rnd > 80 then
				actor:CallForHelp(currentEnemy)
			end

			actor:SetState('fear')
			return
		end

		local data = actor:GetStateData()

		if data.calling_time == nil then
			data.calling_time = CurTime() + math_random(7, 15)
		else
			if data.calling_time < CurTime() then
				for _, enemy in pairs(actor.enemies) do
					if IsValid(enemy) and not hook_Run('BGN_PreCallingPolice', actor, enemy) then
						if asset:HasWanted(enemy) then
							local WantedClass = asset:GetWanted(enemy)
							WantedClass:UpdateWanted(enemy)
						else
							asset:AddWanted(enemy)
							EmitSound(table_RandomBySeq(phone_911_sounnds), npc:GetPos(), npc_index, CHAN_AUTO, 1, 140, 0, 100)
						end
					end
				end

				if not hook_Run('BGN_PostCallingPolice', actor) then
					actor:SetState('fear')
				end
			else
				if not actor:HasSequence('Crouch_IdleD') then
					actor:SetNextSequence('Crouch_To_Stand')
					actor:PlayStaticSequence('Crouch_IdleD', true, 8)
				end

				data.btn_click_delay = data.btn_click_delay or 0
				if data.btn_click_delay < CurTime() then
					EmitSound(table_RandomBySeq(phone_beep_sounnds), npc:GetPos(), npc_index, CHAN_AUTO, 1, 120, 0, 100)
					data.btn_click_delay = CurTime() + math_random(.3, 1.2)
				end
			end
		end
	end
})