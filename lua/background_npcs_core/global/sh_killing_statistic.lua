local bgNPC = bgNPC
local IsValid = IsValid
local CLIENT = CLIENT
local pairs = pairs
local table_Count = table.Count
local hook_Run = hook.Run
--
local _statistic_table = {}

if CLIENT then
	snet.RegisterCallback('bgn_killing_stats_set', function(_, attacker, npc_type, new_value)
		if not IsValid(attacker) or not npc_type or not new_value then return end
		local data = _statistic_table
		data[attacker] = data[attacker] or {}
		data[attacker][npc_type] = new_value
		hook_Run('BGN_SetKillingStatistic', attacker, npc_type, new_value)
	end)

	snet.RegisterCallback('bgn_killing_stats_reset', function(_, attacker)
		if not IsValid(attacker) or not _statistic_table[attacker] then return end
		_statistic_table[attacker] = nil
		hook_Run('BGN_ResetKillingStatistic', attacker)
	end)

	snet.RegisterCallback('bgn_killing_stats_reset_all', function()
		_statistic_table = {}
		hook_Run('BGN_ResetAllKillingStatistic')
	end)
else
	function bgNPC:AddKillingStatistic(attacker, actor)
		_statistic_table[attacker] = _statistic_table[attacker] or {}

		local npc_type = actor:GetType()
		_statistic_table[attacker][npc_type] = _statistic_table[attacker][npc_type] or 0
		_statistic_table[attacker][npc_type] = _statistic_table[attacker][npc_type] + 1

		local new_value = _statistic_table[attacker][npc_type]
		snet.InvokeAll('bgn_killing_stats_set', attacker, npc_type, new_value)
		hook_Run('BGN_SetKillingStatistic', attacker, npc_type, new_value)

		return _statistic_table[attacker][npc_type]
	end

	function bgNPC:ResetKillingStatistic(attacker)
		if not _statistic_table[attacker] then return end
		_statistic_table[attacker] = {}
		snet.InvokeAll('bgn_killing_stats_reset', attacker)
		hook_Run('BGN_ResetKillingStatistic', attacker)
	end

	function bgNPC:ResetKillingStatisticAll()
		_statistic_table = {}
		snet.InvokeAll('bgn_killing_stats_reset_all')
		hook_Run('BGN_ResetAllKillingStatistic')
	end

	hook.Add('PostCleanupMap', 'BGN_ResetWantedKillingStatistic', function()
		bgNPC:ResetKillingStatisticAll()
	end)
end

function bgNPC:GetKillingStatistic(attacker, npc_type)
	if _statistic_table[attacker] then
		if not npc_type then
			return _statistic_table[attacker]
		elseif _statistic_table[attacker][npc_type] then
			return _statistic_table[attacker][npc_type]
		end
	end
	return {}
end

function bgNPC:GetKillingStatisticSumm(attacker)
	if not _statistic_table[attacker] then return 0 end
	if table_Count(_statistic_table[attacker]) == 0 then return 0 end

	local summ = 0
	for _, count in pairs(_statistic_table[attacker]) do
		summ = summ + count
	end

	return summ
end