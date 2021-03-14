local asset = bgNPC:GetModule('wanted')

bgNPC:SetStateAction('retreat', function(actor)
	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0
	data.updatePoint = data.updatePoint or CurTime() + 5
	data.cooldown = data.cooldown or CurTime() + 20

	local enemy = actor:GetEnemy()
	if IsValid(enemy) then
		data.target_point = data.target_point or actor:GetDistantPointInRadius(1000)
	else
		data.target_point = data.target_point or actor:GetDistantPointToPoint(1000, enemy:GetPos())
	end

	-- if actor:TargetsCount() ~= 0 then
	-- 	actor:SetState(actor:GetReactionForDamage())
	-- 	goto skip
	-- end

	if IsValid(enemy) and bgNPC:IsTargetRay(npc, enemy) then
		data.cooldown = CurTime() + 20
	end

	if not asset:HasWanted(npc) and data.cooldown < CurTime() then
		actor:RandomState()
		return
	end

	if data.updatePoint < CurTime() then
		if IsValid(enemy) then
			data.target_point = actor:GetDistantPointInRadius(1000)
		else
			data.target_point = actor:GetDistantPointToPoint(1000, enemy:GetPos())
		end
		actor:WalkToPos(data.target_point, 'run')
		data.updatePoint = CurTime() + 5
	end
end)