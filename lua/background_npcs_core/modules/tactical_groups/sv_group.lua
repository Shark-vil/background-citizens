bgNPC.TacticalGroups = {}

local function Instance()
	local private = {}
	private.actors = {}
	private.tactical = math.random(0, 1)

	local public = {}

	function public:AddActor(actor)
		table.insert(private.actors, actor)
	end

	function public:GetActors()
		for i = #private.actors, 1, -1 do
			local actor = private.actors[i]
			if not actor or not actor:IsAlive() then
				table.remove(private.actors, i)
			end
		end

		for _, actor1 in ipairs(private.actors) do
			for _, actor2 in ipairs(private.actors) do
				if actor1 ~= actor2 and actor1:GetPos():DistToSqr(actor2:GetPos()) >= 1000000 then
					table.RemoveByValue(private.actors, actor1)
					break
				end
			end
		end

		return private.actors
	end

	function public:Count()
		return #self:GetActors()
	end

	function public:ExistsActor(actor)
		return table.HasValueBySeq(self:GetActors(), actor)
	end

	function public:GetSortedActors()
		local actors = self:GetActors()

		if private.tactical == 1 then
			table.sort(actors, function(a, b)
				if a and b and a:IsAlive() and b:IsAlive() then
					local npc_1 = a:GetNPC()
					local npc_2 = b:GetNPC()
					return npc_1:Health() > npc_2:Health()
				end
			end)

			return actors
		else
			return table.shuffle(actors)
		end
	end

	return public
end

local function GetTacticalGroup(actor)
	for i = #bgNPC.TacticalGroups, 1, -1 do
		local group = bgNPC.TacticalGroups[i]
		if not group or group:Count() == 0 then
			table.remove(bgNPC.TacticalGroups, i)
			continue
		end

		if group:ExistsActor(actor) then return group end
	end

	local new_group = Instance()
	new_group:AddActor(actor)
	local index = table.insert(bgNPC.TacticalGroups, new_group)
	return bgNPC.TacticalGroups[index]
end

local function CalcTacticalGroup(team_name)
	local max_group_size = 3

	for _, police in ipairs(bgNPC:GetAllByTeam(team_name)) do
		if not police or not police:IsAlive() then continue end
		if not slib.chance(10) then continue end

		local tactical_group = GetTacticalGroup(police)
		if tactical_group:Count() == max_group_size then continue end

		local npc = police:GetNPC()
		for _, actor in ipairs(bgNPC:GetAllByRadius(npc:GetPos(), 700)) do
			if tactical_group:Count() == max_group_size then break end
			if not actor or not actor:IsAlive() or not actor:HasTeam(team_name) or actor == police then
				continue
			end

			if tactical_group:ExistsActor(actor) then
				continue
			end

			local actor_tactical_group = GetTacticalGroup(actor)
			if actor_tactical_group:Count() > 1 then continue end

			tactical_group:AddActor(actor)

			for i = #bgNPC.TacticalGroups, 1, -1 do
				local group = bgNPC.TacticalGroups[i]
				if group ~= tactical_group and group:ExistsActor(actor) then
					table.remove(bgNPC.TacticalGroups, i)
				end
			end
		end
	end
end

timer.Create('found_npc_group', 1, 0, function()
	CalcTacticalGroup('police')
	CalcTacticalGroup('bandits')

	for _, tactical_group in ipairs(bgNPC.TacticalGroups) do
		if tactical_group and tactical_group:Count() > 1 then
			local actors = tactical_group:GetSortedActors()
			local leader = actors[1]
			local leader_npc = leader:GetNPC()
			local leader_npc_pos = leader_npc:GetPos()
			local leader_center_pos = leader_npc:LocalToWorld(leader_npc:OBBCenter())
			local forward = leader_npc:GetForward() * 150
			local offset = 20
			local leftside = true

			for _, actor in ipairs(actors) do
				actor.movement_order = false

				if actor == leader then continue end
				if actor.movement_order_delay and actor.movement_order_delay > CurTime() then continue end

				local right = leader_npc:GetRight() * (leftside and offset or -offset)
				local move_pos = leader_npc_pos - forward + right

				actor.movement_order = true
				actor:WalkToPos(move_pos, 'run')
				actor.movement_order = false

				local actor_npc = actor:GetNPC()
				local actor_center_pos = actor_npc:LocalToWorld(actor_npc:OBBCenter())
				local start_pos = actor_npc:LocalToWorld(actor_npc:OBBCenter())
				debugoverlay.Line(start_pos, move_pos, 1, Color(8, 222, 250))
				debugoverlay.Sphere(move_pos, 10, 1, Color(8, 222, 250))

				debugoverlay.Line(leader_center_pos, actor_center_pos, 1, Color(8, 250, 60))
				debugoverlay.Sphere(leader_center_pos, 10, 1, Color(250, 85, 8))

				leftside = not leftside
			end
		end
	end
end)

hook.Add('BGN_PreSetWalkPos', 'npc_groups', function(actor, pos)
	local tactical_group = GetTacticalGroup(actor)
	if tactical_group and tactical_group:Count() > 1 then
		local actors = tactical_group:GetSortedActors()
		if actors[1] ~= actor and not actor.movement_order then
			return false
		end
	end
end)