bgNPC:SetStateAction('calling_police', {
	update = function(actor)
		local enemy = actor:GetEnemy()
		if not IsValid(enemy) then return end

		local TargetActor = bgNPC:GetActor(enemy)
		if TargetActor ~= nil and TargetActor:HasTeam('police') then
			actor:SetState('fear')
			return
		end

		local npc = actor:GetNPC()

		if not GetConVar('bgn_enable_wanted_mode'):GetBool() or #bgNPC:GetAllByType('police') == 0 then
			actor:SetState('fear')
			return
		end

		-- 90000 = 300 ^ 2
		if not bgNPC:IsTargetRay(npc, enemy) or npc:GetPos():DistToSqr(enemy:GetPos()) < 90000 then
			local rnd = math.random(0, 100)
			if rnd > 80 then
				actor:CallForHelp(enemy)
			end

			actor:SetState('fear')
			return
		end

		local data = actor:GetStateData()
		
		if data.calling_time == nil then
			data.calling_time = CurTime() + 15
			npc:EmitSound('buttons/button19.wav', 200, 100, 1, CHAN_AUTO)
		else
			if data.calling_time < CurTime() then
				local asset = bgNPC:GetModule('wanted')

				do
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
	end
})