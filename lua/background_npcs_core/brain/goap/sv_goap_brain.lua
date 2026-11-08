--[[
	GOAPBrain: plans what an actor does while it has enemies (see sv_goap.lua and sv_goap_actions.lua).
	Without enemies it behaves exactly like FSMBrain (random calm states).

	Loop: sensors refresh the world state (every SENSE_PERIOD, or right away on events), the goal with the
	highest priority is picked, the cached plan for (state, goal) is executed action by action.
	An action runs its FSM state; when the state leaves on its own (validator, pre_start redirect, lock)
	the action is blocked for a while and the brain replans.

	Reactions: Actor:GetReactionForDamage/Protect ask the brain (PickReaction), so the event code that
	sets reaction states uses the plan instead of a weighted random pick. "ignore" in the config still
	keeps its chance.
--]]

local GOAP = bgNPC.GOAP
local FSMBrain = bgNPC.FSMBrain
local PickWeighted = bgNPC.Actor.Helpers.PickWeighted

local SENSE_PERIOD = 1
local BLOCK_TIME = 5
-- states the plan never interrupts: a surrendering actor keeps its enemies until the arrest ends
local HOLD_STATES = { arrest_surrender = true }

local GOAPBrain = bgNPC.Class('BGN_GOAPBrain', FSMBrain)
bgNPC.GOAPBrain = GOAPBrain

function GOAPBrain:Init(actor)
	FSMBrain.Init(self, actor)
	self.set_name = GOAP.SetFor(actor)
	self.priorities = GOAP.sets[self.set_name]
	self.actions = GOAP.ActionsFor(actor)
	self.ws = 0
	self.next_sense = 0
	self.blocked = {}
	self:ResetPlan()
end

function GOAPBrain:ResetPlan()
	self.plan = nil
	self.step = 1
	self.goal = nil
	self.entered = nil
end

function GOAPBrain:Sense(force)
	local now = CurTime()
	if not force and now < self.next_sense then return end
	self.next_sense = now + SENSE_PERIOD

	local ws = GOAP.Sense(self.actor)
	if ws ~= self.ws then
		self.ws = ws
		self:ResetPlan()
	end
end

function GOAPBrain:AvailableActions()
	local now = CurTime()
	local list, names = {}, {}
	for _, action in ipairs(self.actions) do
		if (self.blocked[action.name] or 0) <= now then
			list[#list + 1] = action
			names[#names + 1] = action.name
		end
	end
	return list, table.concat(names, ',')
end

-- @return table|nil plan, Goal|nil goal for the world state ws
function GOAPBrain:MakePlan(ws)
	local actions, actions_key = self:AvailableActions()
	local best_plan, best_goal, best_priority = nil, nil, 0

	for goal_name, priority_of in pairs(self.priorities) do
		local goal = GOAP.goals[goal_name]
		local priority = priority_of(ws)
		if goal and priority > best_priority and not goal:IsSatisfied(ws) then
			local plan = GOAP.Plan(ws, goal, actions, actions_key)
			if plan and #plan ~= 0 then
				best_plan, best_goal, best_priority = plan, goal, priority
			end
		end
	end

	return best_plan, best_goal
end

function GOAPBrain:Block(action)
	self.blocked[action.name] = CurTime() + BLOCK_TIME
	self.replan_at = CurTime() + BLOCK_TIME -- the plan made without the action is replaced once it is free again
	self:ResetPlan()
end

function GOAPBrain:Update()
	local actor = self.actor

	if actor:HasNoEnemies() then
		if self.plan then self:ResetPlan() end
		return FSMBrain.Update(self)
	end

	if HOLD_STATES[actor:GetState()] then return FSMBrain.Update(self) end

	self:Sense()

	if self.replan_at and self.replan_at <= CurTime() then
		self.replan_at = nil
		self:ResetPlan()
	end

	if not self.plan then
		self.plan, self.goal = self:MakePlan(self.ws)
		self.step = 1
	end

	local action = self.plan and self.plan[self.step]
	if action and action:IsDone(self.ws) then
		self.step = self.step + 1
		self.entered = nil
		action = self.plan[self.step]
	end

	if action then
		local state = actor:GetState()
		if self.entered == action and not action:Runs(state) then
			-- the state ended or redirected on its own
			self:Block(action)
		elseif not action:Runs(state) then
			if not action.prepare or action.prepare(actor) then actor:SetState(action.state) end
			if action:Runs(actor:GetState()) then
				self.entered = action
			else
				self:Block(action)
			end
		end
	end

	return FSMBrain.Update(self)
end

-- @param reactions table { state = weight } from the actor config
-- @param enemy entity|nil who the actor reacts to; without it the enemy facts come from the nearest enemy
-- @return string reaction state
function GOAPBrain:PickReaction(reactions, enemy)
	local roll = PickWeighted(reactions)
	if roll == 'ignore' or roll == 'none' then return roll end

	-- The enemy is added right after the reaction is picked, so plan as if it already exists.
	local ws = bit.bor(GOAP.Sense(self.actor, enemy), GOAP.Fact('has_enemy'))
	local first = (self:MakePlan(ws) or {})[1]
	if not first or (first.prepare and not first.prepare(self.actor)) then return roll end
	return first.state
end

function GOAPBrain:OnEvent(name)
	if name == 'enemy_added' or name == 'damaged' then
		self.next_sense = 0
		self.actor.next_brain = 0 -- react on the next update pass, not after the LOD period
	elseif name == 'enemies_cleared' then
		self:ResetPlan()
	end
end

-- @return string debug text: set, goal, plan and facts
function GOAPBrain:Describe()
	local names = {}
	for i, action in ipairs(self.plan or {}) do
		names[#names + 1] = (i == self.step and '>' or '') .. action.name
	end
	return string.format('%s | goal: %s | plan: %s | %s', self.set_name, self.goal and self.goal.name or '-',
		#names ~= 0 and table.concat(names, ' ') or '-', GOAP.Describe(self.ws))
end

bgNPC.Brain.Register('goap', GOAPBrain)

local function Notify(actor, name)
	local brain = actor and actor.brain
	if brain then brain:OnEvent(name) end
end

hook.Add('BGN_AddActorEnemy', 'BGN_GOAPBrainEvents', function(actor) Notify(actor, 'enemy_added') end)
hook.Add('BGN_ResetEnemiesForActor', 'BGN_GOAPBrainEvents', function(actor) Notify(actor, 'enemies_cleared') end)
hook.Add('EntityTakeDamage', 'BGN_GOAPBrainEvents', function(target)
	if target:IsNPC() or target:IsNextBot() then Notify(bgNPC.Actors.Get(target), 'damaged') end
end)

bgNPC.Commands.Register('bgn_goap_debug', {
	admin = true,
	help = 'Prints the GOAP state of the actor you look at.',
	server = function(ply)
		if not IsValid(ply) then return end
		local actor = bgNPC.Actors.Get(ply:GetEyeTrace().Entity)
		local text = actor and actor.brain and actor.brain.Describe and actor.brain:Describe()
			or 'Look at an actor with the GOAP brain.'
		ply:ChatPrint('[Background NPCs] ' .. text)
	end,
})
