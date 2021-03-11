local asset = bgNPC:GetModule('wanted')

bgNPC:SetStateAction('retreat', function(actor)
	local npc = actor:GetNPC()
	local data = actor:GetStateData()

	data.delay = data.delay or 0
	data.updatePoint = data.updatePoint or CurTime() + 5
	data.cooldown = data.cooldown or CurTime() + 20
	data.target_point = data.target_point or actor:GetDistantPointInRadius(1500)

	-- if actor:TargetsCount() ~= 0 then
	-- 	actor:SetState(actor:GetReactionForDamage())
	-- 	goto skip
	-- end

	local target = actor:GetNearTarget()
	if IsValid(target) and bgNPC:IsTargetRay(npc, target) then
		data.cooldown = CurTime() + 20
	end

	if not asset:HasWanted(npc) and data.cooldown < CurTime() then
		actor:RandomState()
		return
	end

	if data.updatePoint < CurTime() then
		data.target_point = actor:GetDistantPointInRadius(1500)
		actor:WalkToPos(data.target_point, 'run')
		data.updatePoint = CurTime() + 5
	end
end)