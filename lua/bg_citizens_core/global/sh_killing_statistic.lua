if CLIENT then
	net.RegisterCallback('bgn_sync_killing_statistic', function(ply, data)
		bgNPC.killing_statistic = data
	end)
end

function bgNPC:AddKillingStatistic(attacker, actor)
	self.killing_statistic[attacker] = self.killing_statistic[attacker] or {}

	local type = actor:GetType()
	self.killing_statistic[attacker][type] = self.killing_statistic[attacker][type] or 0
	self.killing_statistic[attacker][type] = self.killing_statistic[attacker][type] + 1

	if SERVER then
		net.InvokeAll('bgn_sync_killing_statistic', self.killing_statistic)
	end

	return self.killing_statistic[attacker][type]
end

function bgNPC:ResetKillingStatistic(attacker)
	self.killing_statistic[attacker] = {}

	if SERVER then
		net.InvokeAll('bgn_sync_killing_statistic', self.killing_statistic)
	end
end

function bgNPC:ResetKillingStatisticAll()
	for _, ply in ipairs(player.GetAll()) do
		self.killing_statistic[ply] = {}
	end

	if SERVER then
		net.InvokeAll('bgn_sync_killing_statistic', self.killing_statistic)
	end
end

function bgNPC:GetKillingStatistic(attacker, type)
	self.killing_statistic[attacker] = self.killing_statistic[attacker] or {}
	if type == nil then
		return self.killing_statistic[attacker]
	else
		self.killing_statistic[attacker][type] = self.killing_statistic[attacker][type] or 0
		return self.killing_statistic[attacker][type]
	end
end

function bgNPC:GetKillingStatisticSumm(attacker)
	self.killing_statistic[attacker] = self.killing_statistic[attacker] or {}
	if table.Count(self.killing_statistic[attacker]) == 0 then
		return 0
	end
	
	local summ = 0
	for _, count in pairs(self.killing_statistic[attacker]) do
		summ = summ + count
	end
	return summ
end

hook.Add('PostCleanupMap', 'BGN_ResetKillingStatistic', function()
	for _, ply in ipairs(player.GetAll()) do
		bgNPC.killing_statistic[ply] = {}
	end
end)
