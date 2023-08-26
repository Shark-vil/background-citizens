local cvar_bgn_module_tactical_groups = GetConVar('bgn_module_tactical_groups')
local math_random = math.random
local table_remove = table.remove
local table_insert = table.insert
local table_sort = table.sort
local table_shuffle = table.shuffle
local table_HasValueBySeq = table.HasValueBySeq
local table_RemoveByValue = table.RemoveByValue
local debugoverlay_Line = debugoverlay.Line
local debugoverlay_Sphere = debugoverlay.Sphere
local CurTime = CurTime
local ipairs = ipairs
local isfunction = isfunction
local _color_8_255_250 = Color(8, 222, 250)
local _color_8_250_60 = Color(8, 250, 60)
local _color_250_85_0 = Color(250, 85, 8)
local _tactical_groups_storage = {}
--

local function Instance()
	local private = {}
	private.actors = {}
	private.tactical = math_random(0, 1)

	local public = {}

	function public:AddActor(actor)
		table_insert(private.actors, actor)
	end

	function public:GetActors()
		for i = #private.actors, 1, -1 do
			local actor = private.actors[i]
			if not actor or not actor:IsAlive() then
				table_remove(private.actors, i)
			else
				local npc = actor:GetNPC()
				if not npc.GetActiveWeapon or not isfunction(npc.GetActiveWeapon) or not IsValid(npc:GetActiveWeapon()) then
					table_remove(private.actors, i)
				end
			end
		end

		for _, actor1 in ipairs(private.actors) do
			for _, actor2 in ipairs(private.actors) do
				if actor1 ~= actor2 and actor1:GetPos():DistToSqr(actor2:GetPos()) >= 1000000 then
					table_RemoveByValue(private.actors, actor1)
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
		return table_HasValueBySeq(self:GetActors(), actor)
	end

	function public:GetSortedActors()
		local actors = self:GetActors()

		if private.tactical == 1 then
			table_sort(actors, function(a, b)
				if a and b and a:IsAlive() and b:IsAlive() then
					local npc_1 = a:GetNPC()
					local npc_2 = b:GetNPC()
					return npc_1:Health() > npc_2:Health()
				end
			end)

			return actors
		else
			return table_shuffle(actors)
		end
	end

	return public
end

local function GetTacticalGroup(actor)
	for i = #_tactical_groups_storage, 1, -1 do
		local group = _tactical_groups_storage[i]
		if not group or group:Count() == 0 then
			table_remove(_tactical_groups_storage, i)
			continue
		end

		if group:ExistsActor(actor) then return group end
	end

	local new_group = Instance()
	new_group:AddActor(actor)
	local index = table_insert(_tactical_groups_storage, new_group)
	return _tactical_groups_storage[index]
end

local function CalcTacticalGroup()
	local max_group_size = 3

	for _, target_actor in ipairs(bgNPC:GetAll()) do
		-- if not slib.chance(10) then continue end
		if not target_actor or not target_actor:IsAlive() then continue end
		if not target_actor:EqualStateGroup('danger') then continue end

		local npc = target_actor:GetNPC()
		if not npc.GetActiveWeapon or not isfunction(npc.GetActiveWeapon) or not IsValid(npc:GetActiveWeapon()) then
			continue
		end

		local tactical_group = GetTacticalGroup(target_actor)
		if tactical_group:Count() == max_group_size then continue end

		for _, actor in ipairs(bgNPC:GetAllByRadius(npc:GetPos(), math_random(500, 700))) do
			if tactical_group:Count() == max_group_size then break end
			if not actor or not actor:IsAlive() or not actor:HasTeam(target_actor) or actor == target_actor then
				continue
			end

			if tactical_group:ExistsActor(actor) then
				continue
			end

			local actor_tactical_group = GetTacticalGroup(actor)
			if actor_tactical_group:Count() > 1 then continue end

			tactical_group:AddActor(actor)

			for i = #_tactical_groups_storage, 1, -1 do
				local group = _tactical_groups_storage[i]
				if group ~= tactical_group and group:ExistsActor(actor) then
					table_remove(_tactical_groups_storage, i)
				end
			end
		end
	end
end

local function MovementTacticalGroup()
	for _, tactical_group in ipairs(_tactical_groups_storage) do
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
				if actor == leader or actor:IsMeleeWeapon() then continue end
				if actor.movement_order_delay and actor.movement_order_delay > CurTime() then continue end

				local right = leader_npc:GetRight() * (leftside and offset or -offset)
				local move_pos = leader_npc_pos - forward + right

				actor.movement_order = true
				actor:WalkToPos(move_pos, 'run')
				actor.movement_order = false

				local actor_npc = actor:GetNPC()
				local actor_center_pos = actor_npc:LocalToWorld(actor_npc:OBBCenter())
				local start_pos = actor_npc:LocalToWorld(actor_npc:OBBCenter())
				debugoverlay_Line(start_pos, move_pos, 1, _color_8_255_250)
				debugoverlay_Sphere(move_pos, 10, 1, _color_8_255_250)

				debugoverlay_Line(leader_center_pos, actor_center_pos, 1, _color_8_250_60)
				debugoverlay_Sphere(leader_center_pos, 10, 1, _color_250_85_0)

				leftside = not leftside
			end
		end
	end
end

local function TacticalGroupUpdateTimer()
	CalcTacticalGroup()
	MovementTacticalGroup()
end

local function TacticalGroupWalkOverrideHook(actor, pos)
	if not actor or not actor:IsAlive() or not actor:EqualStateGroup('danger') then
		return
	end

	local tactical_group = GetTacticalGroup(actor)
	if tactical_group and tactical_group:Count() > 1 then
		local actors = tactical_group:GetSortedActors()
		if actors[1] ~= actor and not actor.movement_order then
			return false
		end
	end
end

function bgNPC:GetTacticalGroupGetFirstEnemy(actor)
	if not cvar_bgn_module_tactical_groups:GetBool() then return end
	for _, group in ipairs(_tactical_groups_storage) do
		if group and group:Count() > 1 and group:ExistsActor(actor) then
			local actors = group:GetSortedActors()
			local leader = actors[1]
			if leader and leader ~= actor and leader:IsAlive() then
				return leader:GetFirstEnemy()
			end
		end
	end
end

function bgNPC:GetTacticalGroupGetNearEnemy(actor)
	if not cvar_bgn_module_tactical_groups:GetBool() then return end
	for _, group in ipairs(_tactical_groups_storage) do
		if group and group:Count() > 1 and group:ExistsActor(actor) then
			local actors = group:GetSortedActors()
			local leader = actors[1]
			if leader and leader ~= actor and leader:IsAlive() then
				return leader:GetNearEnemy()
			end
		end
	end
end

local function Start(arguments)
	timer.Create('BGN_TacticalGroupUpdate', 1, 0, TacticalGroupUpdateTimer)
	hook.Add('BGN_PreSetWalkPos', 'BGN_TacticalGroupWalkOverride', TacticalGroupWalkOverrideHook)
end

local function Stop()
	timer.Remove('BGN_TacticalGroupUpdate')
	hook.Remove('BGN_PreSetWalkPos', 'BGN_TacticalGroupWalkOverride')
	_tactical_groups_storage = {}
end

cvars.AddChangeCallback('bgn_module_tactical_groups', function(_, _, newValue)
	if tonumber(newValue) == 1 then
		Start()
	else
		Stop()
	end
end, 'tg_bgn_module_tactical_groups')

if cvar_bgn_module_tactical_groups:GetBool() then
	Start()
end