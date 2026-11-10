local Assert = bgNPC.Assert
local Statistics = bgNPC.Statistics
--

-- attacker -> { actor_type -> kills }
local kills = {}

hook.Add('BGN_ActorEntityChanged', 'BGN_KillingStatisticRebind', function(_, old, npc)
	if kills[old] then kills[npc], kills[old] = kills[old], nil end
end)

function Statistics.Get(attacker, actor_type)
	local attacker_kills = kills[attacker]

	if not actor_type then return attacker_kills or {} end
	return attacker_kills and attacker_kills[actor_type] or 0
end

function Statistics.GetSum(attacker)
	local attacker_kills = kills[attacker]
	if not attacker_kills then return 0 end

	local sum = 0
	for _, count in pairs(attacker_kills) do
		sum = sum + count
	end

	return sum
end

local function SetKills(attacker, actor_type, value)
	kills[attacker] = kills[attacker] or {}
	kills[attacker][actor_type] = value
	hook.Run('BGN_SetKillingStatistic', attacker, actor_type, value)
end

local function ResetAttacker(attacker)
	if not kills[attacker] then return false end
	kills[attacker] = nil
	hook.Run('BGN_ResetKillingStatistic', attacker)
	return true
end

local function ResetAll()
	kills = {}
	hook.Run('BGN_ResetAllKillingStatistic')
end

if CLIENT then
	bgNPC.Net.Receive('bgn_killing_stats_set', function(_, attacker, actor_type, value)
		if not IsValid(attacker) or not actor_type or not value then return end
		SetKills(attacker, actor_type, value)
	end)

	bgNPC.Net.Receive('bgn_killing_stats_reset', function(_, attacker)
		if IsValid(attacker) then ResetAttacker(attacker) end
	end)

	bgNPC.Net.Receive('bgn_killing_stats_reset_all', ResetAll)

	return
end

-- Counts a killed actor for the attacker and syncs it to clients.
-- @return number kills of this actor type
function Statistics.AddKill(attacker, actor)
	Assert.Arg(1, attacker, 'entity', 'bgNPC.Statistics.AddKill')
	Assert.Arg(2, actor, 'actor', 'bgNPC.Statistics.AddKill')

	local actor_type = actor:GetType()
	local value = Statistics.Get(attacker, actor_type) + 1

	SetKills(attacker, actor_type, value)
	bgNPC.Net.Send('bgn_killing_stats_set', nil, attacker, actor_type, value)

	return value
end

function Statistics.Reset(attacker)
	if ResetAttacker(attacker) then
		bgNPC.Net.Send('bgn_killing_stats_reset', nil, attacker)
	end
end

function Statistics.ResetAll()
	ResetAll()
	bgNPC.Net.Send('bgn_killing_stats_reset_all', nil)
end

hook.Add('PostCleanupMap', 'BGN_ResetWantedKillingStatistic', Statistics.ResetAll)
