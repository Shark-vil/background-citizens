BG_NPC_CLASS = {}

function BG_NPC_CLASS:Instance(npc, data)
    local obj = {}
    obj.npc = npc
    obj.class = npc:GetClass()
    obj.data = data
    obj.type = data.type

    obj.next_anim = nil
    obj.anim_time = 0
    obj.loop_time = 0
    obj.anim_is_loop = false
    obj.anim_name = ''
    obj.is_animated = false
    obj.old_state = nil

    obj.isBgnActor = true
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
        if not IsValid(self.npc) then return end
        
        self.npc:SetNPCState(NPC_STATE_IDLE)
        self.npc:ClearSchedule()
    end

    function obj:AddTarget(ent)
        if self:GetNPC() ~= ent and not table.HasValue(self.targets, ent) then            
            table.insert(self.targets, ent)
        end
    end

    function obj:RemoveTarget(ent)
        if IsValid(ent) and IsValid(self.npc) and ent:IsPlayer() then
            self.npc:AddEntityRelationship(ent, D_NU, 99)
        end
        table.RemoveByValue(self.targets, ent)
    end

    function obj:HasTarget(ent)
        return table.HasValue(self.targets, ent)
    end

    function obj:TargetsCount()
        return table.Count(self.targets)
    end

    function obj:GetNearTarget()
        local target = NULL
        local dist = 0
        local self_npc = self:GetNPC()

        for _, npc in ipairs(self.targets) do
            if IsValid(npc) then
                if not IsValid(target) then
                    target = npc
                    dist = npc:GetPos():DistToSqr(self_npc:GetPos())
                elseif npc:GetPos():DistToSqr(self_npc:GetPos()) < dist then
                    target = npc
                    dist = npc:GetPos():DistToSqr(self_npc:GetPos())
                end
            end
        end

        return target
    end

    function obj:RecalculationTargets()
        for i = #self.targets, 1, -1 do
            local target = self.targets[i]
            if not IsValid(target) then
                table.remove(self.targets, i)
            elseif target:IsPlayer() and target:Health() <= 0 then
                self:GetNPC():AddEntityRelationship(target, D_NU, 99)
                table.remove(self.targets, i)
            end
        end
        return self.targets
    end

    function obj:SetOldState()
        if self.old_state ~= nil then
            self.npc.bgCitizenState = self.old_state
            self.old_state = nil

            if IsValid(self.npc) then
                hook.Run('bgCitizen_SetNPCState', self, 
                    self.npc.bgCitizenState.state, self.npc.bgCitizenState.data)
            end
        end
    end

    function obj:SetState(state, data)
        if SERVET then
            self:ResetSequence()
            self:ClearSchedule()
        end

        -- if IsValid(self.npc) then
        --     print(self.npc:EntIndex(), self.type, state)
        -- end

        if SERVER and (self.npc.bgCitizenState == nil or self.npc.bgCitizenState.state ~= state) 
            and state == 'fear' and math.random(0, 10) <= 1 
        then
            local target = self:GetNearTarget()
            if IsValid(target) and target:GetPos():DistToSqr(self.npc:GetPos()) < 250000 then
                local male_scream = {
                    'ambient/voices/m_scream1.wav',
                    'vo/coast/bugbait/sandy_help.wav',
                    'vo/npc/male01/help01.wav',
                    'vo/Streetwar/sniper/male01/c17_09_help01.wav',
                    'vo/Streetwar/sniper/male01/c17_09_help02.wav'
                }

                local female_scream = {
                    'ambient/voices/f_scream1.wav',
                    'vo/canals/arrest_helpme.wav',
                    'vo/npc/female01/help01.wav',
                    'vo/npc/male01/help01.wav',
                }

                local npc_model = self.npc:GetModel()
                local scream_sound = nil
                if tobool(string.find(npc_model, 'male_*')) then
                    scream_sound = table.Random(male_scream)
                elseif tobool(string.find(npc_model, 'female_*')) then
                    scream_sound = table.Random(female_scream)
                else
                    scream_sound = table.Random(table.Merge(male_scream, female_scream))
                end

                self.npc:EmitSound(scream_sound, 450, 100, 1, CHAN_AUTO)
            end
        end

        self.old_state = self.npc.bgCitizenState
        self.npc.bgCitizenState = { state = state, data = (data or {}) }

        if IsValid(self.npc) then
            hook.Run('bgCitizen_SetNPCState', self, 
                self.npc.bgCitizenState.state, self.npc.bgCitizenState.data)
        end

        return self.npc.bgCitizenState
    end

    function obj:Walk()
        self:SetState('walk', {
            schedule = SCHED_FORCED_GO,
            runReset = 0
        })
    end

    function obj:Idle(idle_time)
        self:SetState('idle', {
            delay = CurTime() + idle_time
        })
    end

    function obj:Fear()
        self:SetState('fear', {
            delay = 0
        })
    end

    function obj:Defense()
        self:SetState('defense', {
            delay = 0
        })
    end

    function obj:HasTeam(team_value)
        if self.data.team ~= nil and team_value ~= nil then
            if istable(team_value) then
                if team_value.isBgnActor then
                    team_value = team_value:GetData().team
                end

                for _, team_1 in ipairs(self.data.team) do
                    for _, team_2 in ipairs(team_value) do
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
        if self.npc.bgCitizenState == nil then
            return 'none'
        end
        return self.npc.bgCitizenState.state
    end

    function obj:GetStateData()
        if self.npc.bgCitizenState == nil then
            return {}
        end
        return self.npc.bgCitizenState.data
    end

    function obj:GetDistantPointInRadius(pos, radius)
        radius = radius or 500
        
        local point = nil
        local dist = 0
        local npc = self:GetNPC()
        local points = bgCitizens:GetAllPointsInRadius(npc:GetPos(), radius)

        for _, value in ipairs(points) do
            if point == nil then
                point = value.pos
                dist = point:DistToSqr(pos)
            elseif value.pos:DistToSqr(pos) > dist then
                point = value.pos
                dist = point:DistToSqr(pos)
            end
        end

        return point 
    end

    function obj:GetClosestPointToPosition(pos, radius)
        radius = radius or 500
        
        local point = nil
        local dist = 0
        local npc = self:GetNPC()
        local points = bgCitizens:GetAllPointsInRadius(npc:GetPos(), radius)

        for _, value in ipairs(points) do
            if point == nil then
                point = value.pos
                dist = point:DistToSqr(pos)
            elseif value.pos:DistToSqr(pos) < dist then
                point = value.pos
                dist = point:DistToSqr(pos)
            end
        end

        return point 
    end

    function obj:GetReactionForDamage()
        local probability = math.random(1, 100)
        local percent, reaction = table.Random(self.data.at_damage)

        if probability > percent then
            local last_percent = 0
            
            for _reaction, _percent in pairs(self.data.at_damage) do
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
        local percent, reaction = table.Random(self.data.at_protect)

        if probability > percent then
            local last_percent = 0
            
            for _reaction, _percent in pairs(self.data.at_protect) do
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

    function obj:SetSchedule(schedule)
        if self:IsSequenceFinished() then
            self.npc:SetSchedule(schedule)
        end
    end

    function obj:IsValidSequence(sequence_name)
        if self.npc:LookupSequence(sequence_name) == -1 then return false end
        return true
    end

    function obj:PlayStaticSequence(sequence_name, loop, loop_time)
        if self:IsValidSequence(sequence_name) then
            if self:HasSequence(sequence_name) and not self:IsSequenceFinished() then
                return true
            end

            local hook_result = hook.Run('bgCitizen_PreNPCStartAnimation', 
                self, sequence_name, loop, loop_time)

            if hook_result ~= nil and isbool(hook_result) and not hook_result then
                return
            end

            self.anim_is_loop = loop or false
            self.anim_name = sequence_name
            if loop_time ~= nil and loop_time ~= 0 then
                self.loop_time = RealTime() + loop_time
            else
                self.loop_time = 0
            end
            local sequence = self.npc:LookupSequence(sequence_name)
            self.anim_time = RealTime() + self.npc:SequenceDuration(sequence)
            self.is_animated = true
            
            self.npc:SetNPCState(NPC_STATE_SCRIPT)
            self.npc:SetSchedule(SCHED_SLEEP)
            self.npc:ResetSequenceInfo()
            self.npc:ResetSequence(sequence)

            hook.Run('bgCitizen_StartedNPCAnimation', self, sequence_name, loop, loop_time)

            -- print(tostring(self.anim_is_loop) .. ' - ' .. self.anim_name)

            return true
        end
        return false
    end

    function obj:SetNextSequence(sequence_name, loop, loop_time, action)
        self.next_anim = {
            sequence_name = sequence_name,
            loop = loop,
            loop_time = loop_time,
            action = action,
        }
    end

    function obj:HasSequence(sequence_name)
        return self.anim_name == sequence_name
    end

    function obj:IsAnimationPlayed()
        return self.is_animated
    end

    function obj:IsSequenceLoopFinished()
        if self:IsLoopSequence() then
            if self.loop_time == 0 then return false end
            return self.loop_time < RealTime()
        end
        return true
    end

    function obj:IsLoopSequence()
        return self.anim_is_loop
    end

    function obj:IsSequenceFinished()
        return self.anim_time <= RealTime()
    end

    function obj:ResetSequence()
        -- self.anim_name = ''
        -- self.anim_time = 0
        -- self.anim_is_loop = false
        
        if self.next_anim ~= nil and self.next_anim.sequence_name ~= self.anim_name then
            self:PlayStaticSequence(self.next_anim.sequence_name,
                self.next_anim.loop, self.next_anim.loop_time)
            if self.next_anim.action ~= nil then
                self.next_anim.action(self)
            end

            self.next_anim = nil
            return
        end

        self.is_animated = false
        self.next_anim = nil
        self:ClearSchedule()
    end

    function npc:GetActor()
        return obj
    end

    npc.isActor = true

    return obj
end

if CLIENT then
    net.RegisterCallback('bg_citizen_change_npc_state', function(ply, npc, state, data)
        if IsValid(npc) then
            local actor = bgCitizens:GetActor(npc)
            if actor ~= nil then
                -- print(tostring(npc), state)
                actor:SetState(state, data)
            end
        end
    end)
else
    hook.Add("bgCitizen_SetNPCState", "InvokeAllNpcChangeState", function(actor, state, data)
        local npc = actor:GetNPC()
        if IsValid(npc) then
            npc.bgCitizenVisibility = true
            npc.bgCitizenVisibilityDelay = CurTime() + 3
            timer.Simple(1.5, function()
                net.InvokeAll('bg_citizen_change_npc_state', npc, state, data)
            end)
        end
    end)

    hook.Add('SetupPlayerVisibility', 'SetupPlayerVisiblyOnSetState', function(ent)
        if ent.bgCitizenVisibility then
            AddOriginToPVS(ent:GetPos())
            if npc.bgCitizenVisibilityDelay < CurTime() then
                ent.bgCitizenVisibility = false
            end
        end
    end)
end