local bgNPC = bgNPC
local math_random = math.random
local CurTime = CurTime
local slib_chance = slib.chance
local table_RandomBySeq = table.RandomBySeq
local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
local math_Clamp = math.Clamp

local function GetRandomFoundPointDistance()
	local result = 0
	if slib_chance(30) then
		result = math_random(slib_chance(30) and 100 or 500, 2500)
	else
		result = math_random(slib_chance(30) and 500 or 1000, 2500)
	end
	return math_Clamp(result, 0, cvar_bgn_spawn_radius:GetInt())
end

local function GetRandomDelayForUpdateWalkTarget()
	return CurTime() + math_random(15, 60)
end

local function GetNextTargetNode(actor)
	local dist = GetRandomFoundPointDistance()
	local points = bgNPC:GetAllPointsInRadius(actor:GetNPC():GetPos(), dist, 'walk')

	if not points or #points == 0 then
		points = bgNPC:GetAllPoints('walk')
	end

	if not points or #points == 0 then
		points = bgNPC:GetAllPoints()
	end

	if not points or #points == 0 then
		return
	end

	return table_RandomBySeq(points)
end

local function UpdateActorMovementType(actor, data)
	if data.updateMovementTypeDelay > CurTime() then return end

	if data.schedule == 'run' then
		if data.timeToResetRunMovementType < CurTime() then
			data.schedule = 'walk'
		end
	elseif slib_chance(5) then
		data.timeToResetRunMovementType = CurTime() + math_random(5, 30)
		data.schedule = 'run'
	end

	data.updateMovementTypeDelay = CurTime() + 1
end

local function UpdateActorTargetPoint(actor, data)
	if data.updateTargetPointDelay > CurTime() then return end

	local node = GetNextTargetNode(actor)
	if not node then return end

	actor:WalkToPos(node.position, data.schedule, 'walk')

	if not actor.walkPath or #actor.walkPath == 0 then return end
	data.updateTargetPointDelay = GetRandomDelayForUpdateWalkTarget()
end

bgNPC:SetStateAction('walk', 'calm', {
	update = function(actor)
		local data = actor:GetStateData()
		data.schedule = data.schedule or 'walk'
		data.timeToResetRunMovementType = data.timeToResetRunMovementType or 0
		data.updateTargetPointDelay = data.updateTargetPointDelay or 0
		data.updateMovementTypeDelay = data.updateMovementTypeDelay or 0

		UpdateActorMovementType(actor, data)
		UpdateActorTargetPoint(actor, data)
	end
})

hook.Add('BGN_ActorFinishedWalk', 'BGN_WalkStateUpdatePoint', function(actor)
	if actor:GetState() ~= 'walk' then return end

	local data = actor:GetStateData()
	local node = GetNextTargetNode(actor)
	if not node then return end

	actor:WalkToPos(node.position, data.schedule, 'walk')
	data.updateTargetPointDelay = GetRandomDelayForUpdateWalkTarget()
end)