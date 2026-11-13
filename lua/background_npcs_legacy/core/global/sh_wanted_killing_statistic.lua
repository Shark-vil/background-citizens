local bgNPC = bgNPC
local pairs = pairs
local table_Count = table.Count
--
local _statistic_table = {}

hook.Add('BGN_SetKillingStatistic', 'BGN_WantedModuleStatistic', function(attacker, npc_type, new_value)
	_statistic_table[attacker] = _statistic_table[attacker] or {}
	_statistic_table[attacker][npc_type] = new_value
end)

hook.Add('BGN_ResetKillingStatistic', 'BGN_WantedModuleStatistic', function(attacker)
	_statistic_table[attacker] = nil
end)

hook.Add('BGN_ResetAllKillingStatistic', 'BGN_WantedModuleStatistic', function(attacker)
	_statistic_table = {}
end)

function bgNPC:GetWantedKillingStatistic(attacker, npc_type)
	if _statistic_table[attacker] then
		if not npc_type then
			return _statistic_table[attacker]
		elseif _statistic_table[attacker][npc_type] then
			return _statistic_table[attacker][npc_type]
		end
	end
	return {}
end

function bgNPC:GetWantedKillingStatisticSumm(attacker)
	if not _statistic_table[attacker] then return 0 end
	if table_Count(_statistic_table[attacker]) == 0 then return 0 end

	local summ = 0
	for _, count in pairs(_statistic_table[attacker]) do
		summ = summ + count
	end

	return summ
end