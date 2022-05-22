local cvar_bgn_enable_wanted_mode = GetConVar('bgn_enable_wanted_mode')

local function IsValidWantedMode()
	if not cvar_bgn_enable_wanted_mode:GetBool() or #bgNPC:GetAllByType('police') == 0 then
		return false
	end
	return true
end

bgNPC:SetStateAction('calling_police', 'danger', {
	pre_start = function(actor)
		if not IsValidWantedMode() then
			return 'fear'
		end
	end,
	update = function(actor)
		local currentEnemy = actor:GetEnemy()
		if not IsValid(currentEnemy) then return end

		local TargetActor = bgNPC:GetActor(currentEnemy)
		if TargetActor ~= nil and TargetActor:HasTeam('police') then
			actor:SetState('fear')
			return
		end

		local npc = actor:GetNPC()

		if not IsValidWantedMode() then
			actor:SetState('fear')
			return
		end

		-- 90000 = 300 ^ 2
		if not bgNPC:IsTargetRay(npc, currentEnemy)
			or npc:GetPos():DistToSqr(currentEnemy:GetPos()) < 90000
		then
			local rnd = math.random(0, 100)
			if rnd > 80 then
				actor:CallForHelp(currentEnemy)
			end

			actor:SetState('fear')
			return
		end

		local data = actor:GetStateData()

		if data.calling_time == nil then
			data.calling_time = CurTime() + 15
			npc:EmitSound('background_npcs/phone_dialing_and_bepp_01.mp3', 200, 100, 1, CHAN_AUTO)
		else
			if data.calling_time < CurTime() then
				local asset = bgNPC:GetModule('wanted')

				for _, enemy in pairs(actor.enemies) do
					if IsValid(enemy) and not hook.Run('BGN_PreCallingPolice', actor, enemy) then
						if asset:HasWanted(enemy) then
							local WantedClass = asset:GetWanted(enemy)
							WantedClass:UpdateWanted(enemy)
						else
							asset:AddWanted(enemy)
						end
					end
				end

				npc:EmitSound('buttons/combine_button1.wav', 200, 100, 1, CHAN_AUTO)

				if not hook.Run('BGN_PostCallingPolice', actor) then
					actor:SetState('fear')
				end
			else
				if not actor:HasSequence('Crouch_IdleD') then
					actor:SetNextSequence('Crouch_To_Stand')
					actor:PlayStaticSequence('Crouch_IdleD', true, 8)
				end

				data.btn_click_delay = data.btn_click_delay or 0
				if data.btn_click_delay < CurTime() then
					npc:EmitSound('buttons/button18.wav', 150, 100, 1, CHAN_AUTO)
					data.btn_click_delay = CurTime() + 1
				end
			end
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger')
	end
})