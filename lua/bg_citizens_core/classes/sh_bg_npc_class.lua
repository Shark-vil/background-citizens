BG_NPC_CLASS = {}

function BG_NPC_CLASS:Instance(npc, data)
    local obj = {}
    obj.npc = npc
    obj.class = npc:GetClass()
    obj.data = data
    obj.type = data.type
    obj.targets = {}

    function obj:GetNPC()
        return self.npc
    end

    function obj:GetData()
        return self.data
    end

    function obj:GetClass()
        return self.class
    end

    function obj:GetType()
        return self.type
    end

    function obj:IsValid()
        return IsValid(self.npc)
    end

    function obj:ClearSchedule()
        self.npc:ClearSchedule()
    end

    function obj:AddTarget(ent)
        if not table.HasValue(self.targets, ent) then
            table.insert(self.targets, ent)
        end
    end

    function obj:RemoveTarget(ent)
        for key, target in pairs(self.targets) do
            if target == ent then
                table.remove(self.targets, key)
                break
            end
        end
    end

    function obj:HasTarget(ent)
        return table.HasValue(self.targets, ent)
    end

    function obj:TargetsCount()
        return table.Count(self.targets)
    end

    function obj:RecalculationTargets()
        local new_table = {}
        for _, ent in pairs(self.targets) do
            if IsValid(ent) then
                if ent:Health() > 0 then
                    table.insert(new_table, ent)
                else
                    self:GetNPC():AddEntityRelationship(ent, D_NU, 99)
                end
            end
        end
        self.targets = new_table
        return self.targets
    end

    function obj:SetState(state, data)
        self.npc:ClearSchedule()
        self.npc.bgCitizenState = { state = state, data = (data or {}) }

        if state == 'fear' and math.random(0, 10) <= 1 then
            self.npc:EmitSound(table.Random({
                'ambient/voices/f_scream1.wav',
                'ambient/voices/m_scream1.wav',
                'vo/canals/arrest_helpme.wav',
                'vo/coast/bugbait/sandy_help.wav',
                'vo/npc/female01/help01.wav',
                'vo/npc/male01/help01.wav',
                'vo/Streetwar/sniper/male01/c17_09_help01.wav',
                'vo/Streetwar/sniper/male01/c17_09_help02.wav'
            }), 500, 100, 1, CHAN_AUTO)
        end

        return self.npc.bgCitizenState
    end

    function obj:SetDefaultState()
        self:SetState('walk', {
            schedule = SCHED_FORCED_GO,
            runReset = 0
        })
    end

    function obj:HasTeam(team_value)
        if self.data.team ~= nil and team_value ~= nil then
            if istable(team_value) then
                for _, team_1 in pairs(self.data.team) do
                    for _, team_2 in pairs(team_value) do
                        if team_1 == team_2 then
                            return true
                        end
                    end
                end
            elseif isstring(team_value) then
                return table.HasValue(self.data.team, team_value)
            end
        end
        return false
    end

    function obj:UpdateStateData(data)
        self.npc.bgCitizenState.data = data
    end

    function obj:HasState(state)
        return (self:GetState() == state)
    end

    function obj:GetState()
        return self.npc.bgCitizenState.state
    end

    function obj:GetStateData()
        return self.npc.bgCitizenState.data
    end

    function obj:GetMovementPointToTarget(pos, radius)
        radius = radius or 500
        
        local point = nil
        local dist = 0
        local npc = self:GetNPC()
        local points = bgCitizens:GetAllPointsInRadius(npc:GetPos(), radius)

        for _, value in pairs(points) do
            if point == nil then
                point = value.pos
                dist = point:Distance(pos)
            elseif value.pos:Distance(pos) < dist then
                point = value.pos
                dist = point:Distance(pos)
            end
        end

        return point 
    end

    function obj:GetReactionForDamage()
        local probability = math.random(1, 100)
        local percent, reaction = table.Random(data.at_damage)

        if probability > percent then
            local last_percent = 0
            
            for _reaction, _percent in pairs(data.at_damage) do
                if _percent > last_percent then
                    percent = _percent
                    reaction = _reaction
                    last_percent = percent
                end
            end
        end

        reaction = reaction or 'ignore'

        return reaction
    end

    function obj:GetReactionForProtect()
        local probability = math.random(1, 100)
        local percent, reaction = table.Random(data.at_protect)

        if probability > percent then
            local last_percent = 0
            
            for _reaction, _percent in pairs(data.at_protect) do
                if _percent > last_percent then
                    percent = _percent
                    reaction = _reaction
                    last_percent = percent
                end
            end
        end

        reaction = reaction or 'ignore'

        return reaction
    end

    return obj
end