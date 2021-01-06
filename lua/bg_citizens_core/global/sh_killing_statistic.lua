bgCitizens.killing_statistic = {}

if CLIENT then
    net.RegisterCallback('bgCitizens_SyncKillingStatistic', function(ply, data)
        bgCitizens.killing_statistic = data
    end)
end

function bgCitizens:AddKillingStatistic(attacker, actor)
    self.killing_statistic[attacker] = self.killing_statistic[attacker] or {}

    local type = actor:GetType()
    self.killing_statistic[attacker][type] = self.killing_statistic[attacker][type] or 0
    self.killing_statistic[attacker][type] = self.killing_statistic[attacker][type] + 1

    if SERVER then
        net.InvokeAll('bgCitizens_SyncKillingStatistic', self.killing_statistic)
    end

    return self.killing_statistic[attacker][type]
end

function bgCitizens:GetKillingStatistic(attacker, type)
    self.killing_statistic[attacker] = self.killing_statistic[attacker] or {}
    if type == nil then
        return self.killing_statistic[attacker]
    else
        self.killing_statistic[attacker][type] = self.killing_statistic[attacker][type] or 0
        return self.killing_statistic[attacker][type]
    end
end