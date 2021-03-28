local asset = bgNPC:GetModule('wanted')

bgNPC:SetStateAction('retreat', {
	update = function(actor)
		local npc = actor:GetNPC()
		local data = actor:GetStateData()

		data.delay = data.delay or 0
		data.updatePoint = data.updatePoint or CurTime() + 5
		data.cooldown = data.cooldown or CurTime() + 20

		local enemy = actor:GetEnemy()
		if IsValid(enemy) then
			data.node = data.node or actor:GetDistantPointToPoint(1000, enemy:GetPos())
		else
			data.node = data.node or actor:GetDistantPointInRadius(1000)
		end

		if IsValid(enemy) and bgNPC:IsTargetRay(npc, enemy) then
			data.cooldown = CurTime() + 20
		end

		if not asset:HasWanted(npc) and data.cooldown < CurTime() then
			actor:RandomState()
			return
		end

		if data.updatePoint < CurTime() then
			if IsValid(enemy) then
				data.node = actor:GetDistantPointToPoint(1000, enemy:GetPos())
			else
				data.node = actor:GetDistantPointInRadius(1000)
			end
			actor:WalkToPos(data.node:GetPos(), 'run')
			data.updatePoint = CurTime() + 5
		end
	end
})