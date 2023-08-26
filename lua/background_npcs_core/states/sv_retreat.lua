local asset = bgNPC:GetModule('wanted')

hook.Add('PreRandomState', 'BGN_ChangeImpingementToRetreat', function(actor)
	if (asset:HasWanted(actor:GetNPC()) or actor:HasState('impingement')) and actor:EnemiesCount() == 0 then
		actor:SetState('retreat')
		return true
	end
end)

bgNPC:SetStateAction('retreat', 'other', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		data.delay = data.delay or 0
		data.update_point_delay = data.update_point_delay or CurTime() + 5
		data.cooldown = data.cooldown or CurTime() + 20
		local enemy = actor:GetNearEnemy()

		if IsValid(enemy) and bgNPC:IsTargetRay(npc, enemy) then
			data.cooldown = CurTime() + 20
		end

		if not asset:HasWanted(npc) and data.cooldown < CurTime() then
			actor:RandomState()
			return
		end

		if data.update_point_delay < CurTime() then
			local position

			if IsValid(enemy) then
				local dist = enemy:GetPos():DistToSqr(npc:GetPos())
				if dist <= 36000 and actor.weapon then
					actor:SetState('defense')
					return
				end

				position = actor:GetDistantPointToPoint(enemy:GetPos(), 1000)
			else
				position = actor:GetDistantPointInRadius(1000)
			end

			if position then
				actor:WalkToPos(position, 'run')
				data.update_point_delay = CurTime() + 5
			end
		end
	end
})