--[[
	GOAP sensors, actions and goal sets used by GOAPBrain.

	Actions run existing FSM states, so all behaviour code stays in brain/fsm/states.
	An actor may only use the actions whose state is in its config reactions ("at_damage" / "at_protect")
	with a weight above zero, so configs keep deciding what an actor is able to do;
	GOAP decides which of those fits the situation.

	Sets (picked by team): police, gangster, citizen. Each set is a list of goals with a priority function.
	Extend with bgNPC.GOAP.RegisterAction / RegisterSet.
--]]

local GOAP = bgNPC.GOAP
local F = GOAP.Fact

local ENEMY_CLOSE_DIST_SQR = 700 ^ 2
local LOW_HEALTH_FRACTION = 0.35
local NOT_WEAPONS = {
	weapon_physgun = true, weapon_physcannon = true, gmod_tool = true, gmod_camera = true,
	weapon_fists = true, none = true,
}

-- ---------------------------------------------------------------------------
-- Sensors: fact -> function(actor, npc, enemy) -> boolean
-- ---------------------------------------------------------------------------

local function IsArmedEntity(ent)
	if not ent.GetActiveWeapon then return false end
	local weapon = ent:GetActiveWeapon()
	return IsValid(weapon) and not NOT_WEAPONS[weapon:GetClass()]
end

local wanted
GOAP.sensors = {
	has_enemy = function(actor, npc, enemy) return IsValid(enemy) end,
	armed = function(actor) return actor.weapon ~= nil end,
	is_police = function(actor) return actor:HasTeam('police') end,
	low_health = function(actor, npc) return npc:Health() < npc:GetMaxHealth() * LOW_HEALTH_FRACTION end,
	enemy_close = function(actor, npc, enemy)
		return IsValid(enemy) and npc:GetPos():DistToSqr(enemy:GetPos()) < ENEMY_CLOSE_DIST_SQR
	end,
	enemy_armed = function(actor, npc, enemy) return IsValid(enemy) and IsArmedEntity(enemy) end,
	wanted = function(actor) return actor:IsWanted() end,
	police_called = function(actor, npc, enemy)
		wanted = wanted or bgNPC.Modules.Get('wanted')
		return IsValid(enemy) and wanted ~= nil and wanted:HasWanted(enemy)
	end,
}

-- @param enemy entity|nil enemy to sense against, the nearest enemy by default
-- @return number world state of the actor
function GOAP.Sense(actor, enemy)
	local npc = actor:GetNPC()
	if not IsValid(npc) then return 0 end

	enemy = IsValid(enemy) and enemy or actor:GetNearEnemy()
	local ws = 0
	for name, sensor in pairs(GOAP.sensors) do
		if sensor(actor, npc, enemy) then ws = bit.bor(ws, F(name)) end
	end
	return ws
end

local function Has(ws, name) return bit.band(ws, F(name)) ~= 0 end
GOAP.Has = Has

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------

GOAP.actions = GOAP.actions or {}

function GOAP.RegisterAction(name, def)
	GOAP.actions[name] = GOAP.Action(name, def)
end

GOAP.RegisterAction('attack', {
	state = 'defense',
	also = { 'go_to_police_car', 'retreat' },
	pre = { has_enemy = true, armed = true },
	effects = { threat_handled = true },
	cost = function(ws)
		local cost = 2
		if Has(ws, 'low_health') then cost = cost + 4 end
		if Has(ws, 'enemy_armed') and not Has(ws, 'is_police') then cost = cost + 2 end
		return cost
	end,
})

GOAP.RegisterAction('flee', {
	state = 'fear',
	also = { 'run_from_danger', 'dyspnea_danger', 'pick_up_weapon' },
	effects = { safe = true },
	cost = 2,
})

-- Needs no config weight: any wanted actor hides from its pursuers, fighting back only when cornered.
GOAP.RegisterAction('hide', {
	state = 'retreat',
	also = { 'defense' },
	always = true,
	pre = { wanted = true },
	effects = { hidden = true },
	cost = 1,
})

GOAP.RegisterAction('call_police', {
	state = 'calling_police',
	trait = true, -- only some actors make the call, see GOAP.ActionsFor
	pre = { has_enemy = true, police_called = false, enemy_close = false },
	effects = { police_called = true },
	cost = 2,
})

-- ---------------------------------------------------------------------------
-- Goal sets
-- ---------------------------------------------------------------------------

GOAP.goals = {
	eliminate = GOAP.Goal('eliminate', { want = { threat_handled = true } }),
	survive = GOAP.Goal('survive', { want = { safe = true } }),
	report = GOAP.Goal('report', { want = { police_called = true } }),
	hide = GOAP.Goal('hide', { want = { hidden = true } }),
}

local function HideWhenWanted(ws) return Has(ws, 'wanted') and 20 or 0 end

-- set name -> { goal name -> priority function(ws) }
GOAP.sets = GOAP.sets or {}

function GOAP.RegisterSet(name, priorities)
	GOAP.sets[name] = priorities
end

GOAP.RegisterSet('police', {
	eliminate = function() return 10 end,
	survive = function(ws) return Has(ws, 'low_health') and 4 or 0 end,
})

GOAP.RegisterSet('gangster', {
	eliminate = function() return 6 end,
	survive = function(ws) return Has(ws, 'low_health') and 8 or 2 end,
	hide = HideWhenWanted,
})

GOAP.RegisterSet('citizen', {
	survive = function(ws)
		local priority = 5
		if Has(ws, 'enemy_armed') then priority = priority + 3 end
		if Has(ws, 'low_health') then priority = priority + 3 end
		return priority
	end,
	eliminate = function(ws)
		if not Has(ws, 'armed') then return 0 end
		-- an armed citizen keeps fighting until it is hurt, an armed enemy alone doesn't scare it off
		return Has(ws, 'low_health') and 3 or 9
	end,
	-- above survive with an armed enemy (8), so a far gunman gets reported; below an armed citizen's fight (9)
	report = function(ws) return Has(ws, 'enemy_close') and 0 or 8.5 end,
	hide = HideWhenWanted,
})

-- @return string set name for the actor
function GOAP.SetFor(actor)
	if isstring(actor.data.goap_set) and GOAP.sets[actor.data.goap_set] then return actor.data.goap_set end
	if actor:HasTeam('police') then return 'police' end
	if actor:HasTeam('bandits') then return 'gangster' end
	return 'citizen'
end

-- @return table actions allowed by the actor config (sorted by name, so the cache key is stable)
function GOAP.ActionsFor(actor)
	local data = actor.data
	local share = {} -- state -> best weight / table total
	for _, reactions in ipairs({ data.at_damage, data.at_protect }) do
		if istable(reactions) then
			local total = 0
			for _, weight in pairs(reactions) do total = total + math.max(0, weight) end
			for state, weight in pairs(reactions) do
				if weight > 0 then share[state] = math.max(share[state] or 0, weight / total) end
			end
		end
	end

	-- A trait action is rolled once per actor with its config share (calling_police 20 -> 20% of actors),
	-- so the config weight still limits how many actors do it.
	local list = {}
	for _, action in SortedPairs(GOAP.actions) do
		local chance = action.always and 1 or share[action.state]
		if chance and (not action.trait or math.random() < chance) then list[#list + 1] = action end
	end
	return list
end

bgNPC.Test.Add('goap.sets', function(check)
	local actions = { GOAP.actions.attack, GOAP.actions.call_police, GOAP.actions.flee }
	local ws = bit.bor(F('has_enemy'), F('armed'))
	local plan = GOAP.Plan(ws, GOAP.goals.eliminate, actions)
	check(plan and plan[1] == GOAP.actions.attack, 'armed citizen can eliminate by attacking')

	plan = GOAP.Plan(F('has_enemy'), GOAP.goals.report, actions)
	check(plan and plan[1] == GOAP.actions.call_police, 'far enemy: call the police')

	plan = GOAP.Plan(bit.bor(F('has_enemy'), F('enemy_close')), GOAP.goals.report, actions)
	check(plan == nil, 'close enemy: cannot call the police')

	local citizen = GOAP.sets.citizen
	ws = bit.bor(F('has_enemy'), F('armed'), F('enemy_armed'))
	check(citizen.eliminate(ws) > citizen.survive(ws), 'armed citizen keeps fighting an armed enemy')
	ws = bit.bor(ws, F('low_health'))
	check(citizen.survive(ws) > citizen.eliminate(ws), 'hurt armed citizen runs')

	ws = bit.bor(F('has_enemy'), F('enemy_armed'))
	check(citizen.report(ws) > citizen.survive(ws), 'unarmed citizen reports a far armed enemy')

	check(GOAP.actions.flee:Runs('run_from_danger'), 'running from danger is still fleeing')

	ws = bit.bor(F('has_enemy'), F('armed'), F('wanted'))
	local gangster = GOAP.sets.gangster
	check(gangster.hide(ws) > gangster.eliminate(ws), 'a wanted gangster hides first')
	plan = GOAP.Plan(ws, GOAP.goals.hide, { GOAP.actions.attack, GOAP.actions.hide })
	check(plan and plan[1] == GOAP.actions.hide, 'hiding runs retreat')
end)
