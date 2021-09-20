local bgNPC = bgNPC
local CLIENT = CLIENT
local SERVER = SERVER
local snet = slib.Components.Network
local ipairs = ipairs
local pairs = pairs
local player = player
local hook = hook
--

if CLIENT then
	snet.RegisterCallback('bgn_sync_wanted_killing_statistic', function(ply, data)
		bgNPC.wanted_killing_statistic = data
	end)
end

function bgNPC:AddWantedKillingStatistic(attacker, actor)
	if not bgNPC:GetModule('wanted'):HasWanted(attacker) then return end

	self.wanted_killing_statistic[attacker] = self.wanted_killing_statistic[attacker] or {}

	local npc_type = actor:GetType()
	self.wanted_killing_statistic[attacker][npc_type] = self.wanted_killing_statistic[attacker][npc_type] or 0
	self.wanted_killing_statistic[attacker][npc_type] = self.wanted_killing_statistic[attacker][npc_type] + 1

	if SERVER then
		snet.InvokeAll('bgn_sync_wanted_killing_statistic', self.wanted_killing_statistic)
	end

	return self.wanted_killing_statistic[attacker][npc_type]
end

function bgNPC:ResetWantedKillingStatistic(attacker)
	self.wanted_killing_statistic[attacker] = {}

	if SERVER then
		snet.InvokeAll('bgn_sync_wanted_killing_statistic', self.wanted_killing_statistic)
	end
end

function bgNPC:ResetWantedKillingStatisticAll()
	for _, ply in ipairs(player.GetAll()) do
		self.wanted_killing_statistic[ply] = {}
	end

	if SERVER then
		snet.InvokeAll('bgn_sync_wanted_killing_statistic', self.wanted_killing_statistic)
	end
end

function bgNPC:GetWantedKillingStatistic(attacker, npc_type)
	self.wanted_killing_statistic[attacker] = self.wanted_killing_statistic[attacker] or {}
	if npc_type == nil then
		return self.wanted_killing_statistic[attacker]
	else
		self.wanted_killing_statistic[attacker][npc_type] = self.wanted_killing_statistic[attacker][npc_type] or 0
		return self.wanted_killing_statistic[attacker][npc_type]
	end
end

function bgNPC:GetWantedKillingStatisticSumm(attacker)
	self.wanted_killing_statistic[attacker] = self.wanted_killing_statistic[attacker] or {}
	if table.Count(self.wanted_killing_statistic[attacker]) == 0 then
		return 0
	end

	local summ = 0
	for _, count in pairs(self.wanted_killing_statistic[attacker]) do
		summ = summ + count
	end
	return summ
end

hook.Add('PostCleanupMap', 'BGN_ResetWantedKillingStatistic', function()
	bgNPC:ResetWantedKillingStatisticAll()
end)
