local function GetNextNode(actor)
	return table.RandomBySeq(bgNPC:GetAllPointsInRadius(actor:GetNPC():GetPos(), 1500, 'walk'))
end

bgNPC:SetStateAction('walk', 'calm', {
	update = function(actor)
		if not bgNPC.PointsExist then return end
		local data = actor:GetStateData()
		data.schedule = data.schedule or 'walk'
		data.runReset = data.runReset or 0
		data.updatePoint = data.updatePoint or 0

		if data.schedule == 'run' then
			if data.runReset < CurTime() then
				actor:UpdateStateData({
					schedule = 'walk',
					runReset = 0
				})
			end
		elseif math.random(0, 100) == 0 then
			actor:UpdateStateData({
				schedule = 'run',
				runReset = CurTime() + 20
			})
		end

		if data.updatePoint < CurTime() then
			local node = GetNextNode(actor)
			if node then
				actor:WalkToPos(node.position, data.schedule, 'walk')
				if #actor.walkPath == 0 then return end
				data.updatePoint = CurTime() + math.random(15, 30)
			else
				bgNPC:Log('NPC cannot find a point nearby', 'sv_walk')
			end
		end
	end
})

hook.Add('BGN_ActorFinishedWalk', 'BGN_WalkStateUpdatePoint', function(actor)
	if not bgNPC.PointsExist then return end
	if actor:GetState() ~= 'walk' then return end
	bgNPC:Log('NPC has reached the desired point', 'sv_walk')
	local data = actor:GetStateData()
	local node = GetNextNode(actor)
	actor:WalkToPos(node.position, data.schedule, 'walk')
	data.updatePoint = CurTime() + math.random(15, 30)
end)