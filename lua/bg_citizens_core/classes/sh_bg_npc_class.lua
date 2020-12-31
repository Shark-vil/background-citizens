BG_NPC_CLASS = {}

function BG_NPC_CLASS:Instance(npc, data)
    local obj = {}
    obj.npc = npc
    obj.class = npc:GetClass()
    obj.data = data
    obj.type = data.type

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

    function obj:SetState(state, data)
        self.npc:ClearSchedule()
        self.npc.bgCitizenState = { state = state, data = (data or {}) }
        return self.npc.bgCitizenState
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

    return obj
end