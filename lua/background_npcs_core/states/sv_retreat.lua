local asset = bgNPC:GetModule('wanted')

bgNPC:SetStateAction('retreat', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()
		data.delay = data.delay or 0
		data.updatePoint = data.updatePoint or CurTime() + 5
		data.cooldown = data.cooldown or CurTime() + 20
		local enemy = actor:GetNearEnemy()

		if IsValid(enemy) and bgNPC:IsTargetRay(npc, enemy) then
			data.cooldown = CurTime() + 20
		end

		if not asset:HasWanted(npc) and data.cooldown < CurTime() then
			actor:RandomState()
			return
		end

		if data.updatePoint < CurTime() then
			local node

			if IsValid(enemy) then
				node = actor:GetDistantPointToPoint(1000, enemy:GetPos())
			else
				node = actor:GetDistantPointInRadius(1000)
			end

			if node then
				actor:WalkToPos(node:GetPos(), 'run')
				data.updatePoint = CurTime() + 5
			else
				bgNPC:Log('NPC cannot find a point nearby', 'sv_retreat')
			end
		end
	end,
	not_stop = function(actor, state, data, new_state, new_data)
		return actor:EnemiesCount() > 0 and not actor:HasDangerState(new_state)
	end
})