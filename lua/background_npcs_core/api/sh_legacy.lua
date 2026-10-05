--[[
	Backward compatibility for the old "bgNPC:Method()" API.

	Every old method is a thin wrapper around the new namespaced function.
	The addon itself does not use these names anymore; they are kept for
	third-party addons and server configs. With "bgn_debug 1" the first call
	of each deprecated method is reported in the console.
--]]

local bgNPC = bgNPC
local Util = bgNPC.Util
local Actors = bgNPC.Actors
local Points = bgNPC.Points
local Config = bgNPC.Config
local States = bgNPC.States
local Vision = bgNPC.Vision
local Statistics = bgNPC.Statistics
local Modules = bgNPC.Modules
local Modes = bgNPC.Modes
--

local reported = {}

local function ReportDeprecated(old_name, new_name)
	if reported[old_name] or not Util.IsDebug() then return end
	reported[old_name] = true
	MsgN('[Background NPCs] bgNPC:' .. old_name .. '() is deprecated, use ' .. new_name .. '() instead')
end

-- Defines bgNPC:<old_name>(...) that calls the new function without "self".
local function Alias(old_name, new_name, new_func)
	assert(isfunction(new_func), 'Legacy alias target is missing: ' .. new_name)

	bgNPC[old_name] = function(_, ...)
		ReportDeprecated(old_name, new_name)
		return new_func(...)
	end
end

local SHARED_ALIASES = {
	-- Actors
	{ 'GetActor', 'bgNPC.Actors.Get', Actors.Get },
	{ 'IsActor', 'bgNPC.Actors.IsActor', Actors.IsActor },
	{ 'GetActorByUid', 'bgNPC.Actors.GetByUid', Actors.GetByUid },
	{ 'GetFirstActorInList', 'bgNPC.Actors.GetFirst', Actors.GetFirst },
	{ 'GetAll', 'bgNPC.Actors.GetAll', Actors.GetAll },
	{ 'Count', 'bgNPC.Actors.Count', Actors.Count },
	{ 'GetAllByType', 'bgNPC.Actors.GetByType', Actors.GetByType },
	{ 'GetAllByTeam', 'bgNPC.Actors.GetByTeam', Actors.GetByTeam },
	{ 'GetAllByState', 'bgNPC.Actors.GetByState', Actors.GetByState },
	{ 'GetAllNPCs', 'bgNPC.Actors.GetAllNPCs', Actors.GetAllNPCs },
	{ 'GetAllNPCsByType', 'bgNPC.Actors.GetNPCsByType', Actors.GetNPCsByType },
	{ 'GetNear', 'bgNPC.Actors.GetNearest', Actors.GetNearest },
	{ 'GetNearByType', 'bgNPC.Actors.GetNearestByType', Actors.GetNearestByType },
	{ 'GetAllByRadius', 'bgNPC.Actors.GetInRadius', Actors.GetInRadius },
	{ 'HasNPC', 'bgNPC.Actors.HasNPC', Actors.HasNPC },
	{ 'IsTeamOnce', 'bgNPC.Actors.ShareTeam', Actors.ShareTeam },
	{ 'AddNPC', 'bgNPC.Actors.Register', Actors.Register },
	{ 'RemoveNPC', 'bgNPC.Actors.Unregister', Actors.Unregister },
	{ 'ClearRemovedNPCs', 'bgNPC.Actors.ClearRemoved', Actors.ClearRemoved },

	-- Points
	{ 'GetAllPoints', 'bgNPC.Points.GetAll', Points.GetAll },
	{ 'GetAllPointsInRadius', 'bgNPC.Points.GetInRadius', Points.GetInRadius },
	{ 'GetAllIndexPointsInRadius', 'bgNPC.Points.GetIndexesInRadius', Points.GetIndexesInRadius },
	{ 'GetClosestPointInRadius', 'bgNPC.Points.GetClosestInRadius', Points.GetClosestInRadius },
	{ 'GetDistantPointInRadius', 'bgNPC.Points.GetDistantInRadius', Points.GetDistantInRadius },
	{ 'GetClosestPointInChunk', 'bgNPC.Points.GetClosestInChunk', Points.GetClosestInChunk },
	{ 'GetDistantPointInChunk', 'bgNPC.Points.GetDistantInChunk', Points.GetDistantInChunk },
	{ 'GetClosestPointToPointInChunk', 'bgNPC.Points.GetClosestToPosInChunk', Points.GetClosestToPosInChunk },
	{ 'GetDistantPointToPointInChunk', 'bgNPC.Points.GetDistantToPosInChunk', Points.GetDistantToPosInChunk },
	{ 'FindWalkPath', 'bgNPC.Points.FindPath', Points.FindPath },

	-- Config
	{ 'GetActorConfig', 'bgNPC.Config.GetActor', Config.GetActor },
	{ 'ClearActorsConfig', 'bgNPC.Config.ClearCache', Config.ClearCache },
	{ 'ResetConfiguration', 'bgNPC.Config.Reset', Config.Reset },
	{ 'IsActiveNPCType', 'bgNPC.Config.IsTypeActive', Config.IsTypeActive },
	{ 'GetFullness', 'bgNPC.Config.GetFullness', Config.GetFullness },
	{ 'GetLimitActors', 'bgNPC.Config.GetTypeLimit', Config.GetTypeLimit },

	-- States
	{ 'SetStateAction', 'bgNPC.States.Register', States.Register },
	{ 'GetStateGroupName', 'bgNPC.States.GetGroup', States.GetGroup },
	{ 'CallStateAction', 'bgNPC.States.Call', States.Call },
	{ 'StateActionExists', 'bgNPC.States.HasAction', States.HasAction },

	-- Vision
	{ 'IsTargetRay', 'bgNPC.Vision.HasLineOfSight', Vision.HasLineOfSight },
	{ 'NPCIsViewVector', 'bgNPC.Vision.NPCCanSeePos', Vision.NPCCanSeePos },
	{ 'PlayerIsViewVector', 'bgNPC.Vision.PlayerCanSeePos', Vision.PlayerCanSeePos },
	{ 'CanAnyActorSeeEntity', 'bgNPC.Vision.AnyActorSees', Vision.AnyActorSees },
	{ 'CanActorsSeeEntity', 'bgNPC.Vision.ActorsThatSee', Vision.ActorsThatSee },

	-- Statistics (the "wanted" statistic always mirrored the regular one)
	{ 'GetKillingStatistic', 'bgNPC.Statistics.Get', Statistics.Get },
	{ 'GetKillingStatisticSumm', 'bgNPC.Statistics.GetSum', Statistics.GetSum },
	{ 'GetWantedKillingStatistic', 'bgNPC.Statistics.Get', Statistics.Get },
	{ 'GetWantedKillingStatisticSumm', 'bgNPC.Statistics.GetSum', Statistics.GetSum },

	-- Util
	{ 'Log', 'bgNPC.Util.Log', Util.Log },
	{ 'VectorInWater', 'bgNPC.Util.IsVectorInWater', Util.IsVectorInWater },
	{ 'GetActivePlayerTool', 'bgNPC.Util.GetActivePlayerTool', Util.GetActivePlayerTool },
	{ 'GetModule', 'bgNPC.Modules.Get', Modules.Get },

	-- Modes
	{ 'IsPeacefulMode', 'bgNPC.Modes.IsPeaceful', Modes.IsPeaceful },
	{ 'IsFriendMode', 'bgNPC.Modes.IsFriend', Modes.IsFriend },
	{ 'IsAgressiveMode', 'bgNPC.Modes.IsAggressive', Modes.IsAggressive },
}

for _, alias in ipairs(SHARED_ALIASES) do
	Alias(alias[1], alias[2], alias[3])
end

if not SERVER then return end

local Combat = bgNPC.Combat

local SERVER_ALIASES = {
	{ 'SetActorWeapon', 'bgNPC.Combat.EquipActor', Combat.EquipActor },
	{ 'CheckVehicleAttacker', 'bgNPC.Combat.ResolveVehicleAttacker', Combat.ResolveVehicleAttacker },
	{ 'IsEnemyTeam', 'bgNPC.Combat.IsEnemyOfTeam', Combat.IsEnemyOfTeam },
	{ 'GetEnemyFromActorByTarget', 'bgNPC.Combat.ResolveEnemy', Combat.ResolveEnemy },

	{ 'AddKillingStatistic', 'bgNPC.Statistics.AddKill', Statistics.AddKill },
	{ 'ResetKillingStatistic', 'bgNPC.Statistics.Reset', Statistics.Reset },
	{ 'ResetKillingStatisticAll', 'bgNPC.Statistics.ResetAll', Statistics.ResetAll },
}

for _, alias in ipairs(SERVER_ALIASES) do
	Alias(alias[1], alias[2], alias[3])
end
