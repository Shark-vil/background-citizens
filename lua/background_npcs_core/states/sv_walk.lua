local bgNPC = bgNPC
local math_random = math.random
local CurTime = CurTime
local Vector = Vector
local slib_chance = slib.chance
local table_RandomBySeq = table.RandomBySeq
local cvar_bgn_spawn_radius = GetConVar('bgn_spawn_radius')
local math_Clamp = math.Clamp

local function GetRandomFoundPointDistance()
	local result = 0
	local chance = slib_chance(30)
	if slib_chance(30) then
		result = math_random(chance and 100 or 500, 2500)
	else
		result = math_random(chance and 500 or 1000, 2500)
	end
	return math_Clamp(result, 0, cvar_bgn_spawn_radius:GetInt())
end

local function GetRandomDelayForUpdateWalkTarget()
	return CurTime() + math_random(15, 60)
end

local function GetNextMovePosition(actor)
	local npc_pos = actor:GetPos()
	local dist = GetRandomFoundPointDistance()
	local points = bgNPC:GetAllPointsInRadius(npc_pos, dist, 'walk')

	if not points or #points == 0 then
		points = bgNPC:GetAllPoints('walk')
	end

	if not points or #points == 0 then
		points = bgNPC:GetAllPoints()
	end

	if not points or #points == 0 then
		local dist_x = math_random(250, 1000)
		local dist_y = math_random(250, 1000)
		if slib_chance(50) then dist_x = -dist_x end
		if slib_chance(50) then dist_y = -dist_y end
		return Vector(npc_pos.x + dist_x, npc_pos.y + dist_y, npc_pos.z)
	end

	local node = table_RandomBySeq(points)
	return node.position
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

local function UpdateActorTargetPointAsync(actor, data)
	if not data.updateTargetPointDelay or data.updateTargetPointDelay > CurTime() then
		return
	end

	local position = GetNextMovePosition(actor)
	if not position then return end

	actor:WalkToPos(position, data.schedule, 'walk')
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
		UpdateActorTargetPointAsync(actor, data)
	end
})

hook.Add('BGN_ActorFinishedWalk', 'BGN_WalkStateUpdatePoint', function(actor)
	if not actor or not actor:IsAlive() or actor:GetState() ~= 'walk' then return end
	local data = actor:GetStateData()
	data.updateMovementTypeDelay = 0
	data.updateTargetPointDelay = 0
end)