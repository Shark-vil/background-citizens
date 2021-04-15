bgNPC:SetStateAction('run_from_danger', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
      local enemy = actor:GetNearEnemy()

      data.update_run_position_delay = data.update_run_position_delay or 0
      data.call_for_help = data.call_for_help or CurTime() + math.random(20, 30)

		if not IsValid(enemy) or enemy:Health() <= 0 then return end
      local dist = npc:GetPos():DistToSqr(enemy:GetPos())

      if data.call_for_help < CurTime() then
         actor:CallForHelp(enemy)
         data.call_for_help = CurTime() + math.random(20, 30)
      end
		
      if dist > 1000000 and (not data.dyspnea_delay or data.dyspnea_delay < CurTime()) then
			actor:SetState('dyspnea_danger')
      elseif dist < 40000 then
         actor:SetState('fear')
      else
         if data.update_run_position_delay < CurTime() then
				local position = actor:GetDistantPointToPoint(enemy:GetPos(), math.random(700, 1500))
				if position then
					actor:WalkToPos(position, 'run')
					data.update_run_position_delay = CurTime() + math.random(10, 15)
				end
			end
      end
	end
})