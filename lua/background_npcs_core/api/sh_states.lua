local bgNPC = bgNPC
local Assert = bgNPC.Assert
local States = bgNPC.States
--

-- state name -> table of callbacks
bgNPC.state_actions = bgNPC.state_actions or {}
-- state name -> group name ('calm', 'danger', 'guarded', ...)
bgNPC.state_actions_groups = bgNPC.state_actions_groups or {}

--[[
	Registers a state.

	Callbacks (all optional), the actor is always the first argument:
		validator(actor, state, data) -> boolean   can the actor enter the state
		pre_start(actor, state, data) -> true | new_state, new_data
		start(actor, state, data)
		update(actor, state, data)                called by the state machine
		stop(actor, state, data)
		not_stop(actor, state, data, new_state, new_data) -> boolean   block leaving the state
--]]
function States.Register(state_name, group_name, callbacks)
	Assert.NonEmptyString(1, state_name, 'bgNPC.States.Register')
	Assert.Arg(2, group_name, 'string|nil', 'bgNPC.States.Register')
	Assert.Arg(3, callbacks, 'table', 'bgNPC.States.Register')

	bgNPC.state_actions[state_name] = callbacks
	bgNPC.state_actions_groups[state_name] = group_name
end

function States.Exists(state_name)
	return bgNPC.state_actions[state_name] ~= nil
end

-- @return string group name or 'none'
function States.GetGroup(state_name)
	return bgNPC.state_actions_groups[state_name] or 'none'
end

-- Calls a state callback. Returns whatever the callback returns.
function States.Call(state_name, func_name, ...)
	local callbacks = bgNPC.state_actions[state_name]
	if not callbacks then return end

	local func = callbacks[func_name]
	if not func then return end

	return func(...)
end

function States.HasAction(state_name, func_name)
	local callbacks = bgNPC.state_actions[state_name]
	return callbacks ~= nil and callbacks[func_name] ~= nil
end
