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
local OUTNUMBERED_DIST_SQR = 2000 ^ 2
local LOW_HEALTH_FRACTION = 0.35
local SURRENDER_HEALTH_FRACTION = 0.5 -- below this an actor may give up, above it never
local SURRENDER_CHANCE = 8 -- percent per attempt (one per BLOCK_TIME while the conditions hold)
local NOT_WEAPONS = {
	weapon_physgun = true, weapon_physcannon = true, gmod_tool = true, gmod_camera = true,
	weapon_fists = true, none = true,
	weapon_citizenpackage = true, weapon_citizensuitcase = true,
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
	can_surrender = function(actor, npc) return npc:Health() < npc:GetMaxHealth() * SURRENDER_HEALTH_FRACTION end,
	enemy_close = function(actor, npc, enemy)
		return IsValid(enemy) and npc:GetPos():DistToSqr(enemy:GetPos()) < ENEMY_CLOSE_DIST_SQR
	end,
	enemy_armed = function(actor, npc, enemy) return IsValid(enemy) and IsArmedEntity(enemy) end,
	wanted = function(actor) return actor:IsWanted() end,
	in_cover = function(actor) return (actor.cover_until or 0) > CurTime() end, -- set by take_cover
	backup_called = function(actor) return (actor.backup_until or 0) > CurTime() end, -- set by call_backup
	enemy_police = function(actor, npc, enemy)
		local enemy_actor = IsValid(enemy) and bgNPC.Actors.Get(enemy)
		return enemy_actor and enemy_actor:HasTeam('police') or false
	end,
	-- more living enemies than officers within OUTNUMBERED_DIST (only the police plan around it)
	outnumbered = function(actor, npc)
		if actor.enemies_count < 2 or not actor:HasTeam('police') then return false end
		local pos, enemies, officers = npc:GetPos(), 0, 0
		for _, enemy in ipairs(actor.enemies) do
			if IsValid(enemy) and enemy:Health() > 0 and enemy:GetPos():DistToSqr(pos) < OUTNUMBERED_DIST_SQR then
				enemies = enemies + 1
			end
		end
		if enemies < 2 then return false end
		for _, officer in ipairs(bgNPC.Actors.GetByTeam('police')) do
			if officer:IsAlive() and officer:GetPos():DistToSqr(pos) < OUTNUMBERED_DIST_SQR then officers = officers + 1 end
		end
		return enemies > officers
	end,
	surrendered = function(actor) return actor:HasState('arrest_surrender') end,
	police_called = function(actor, npc, enemy)
		wanted = wanted or bgNPC.Modules.Get('wanted')
		return IsValid(enemy) and ((wanted ~= nil and wanted:HasWanted(enemy)) or bgNPC.PoliceKnows(enemy)) -- the police already know of it
	end,
	desperate = function(actor, _, enemy) return bgNPC.Doors.Desperate(actor, enemy) end,
	can_hold_door = function(actor, _, enemy) return bgNPC.Doors.Find(actor, enemy) ~= nil end,
	enemy_bracing = function(actor, _, enemy) return bgNPC.Doors.Blocker(actor, enemy) ~= nil end,
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
		-- an armed enemy or a crowd is cheaper to fight from cover; an outnumbered officer also wants backup
		if Has(ws, 'enemy_armed') or Has(ws, 'outnumbered') then
			if not Has(ws, 'in_cover') then cost = cost + 3 end
			if Has(ws, 'outnumbered') and Has(ws, 'is_police') and not Has(ws, 'backup_called') then cost = cost + 3 end
		end
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

GOAP.RegisterAction('hold_door', {
	state = 'hold_door', always = true,
	pre = { has_enemy = true, desperate = true, can_hold_door = true, is_police = false },
	effects = { door_held = true }, cost = 1,
})

GOAP.RegisterAction('breach_door', {
	state = 'breach_door', always = true,
	pre = { has_enemy = true, is_police = true, enemy_bracing = true },
	effects = { threat_handled = true }, cost = 1,
})

-- attack chains: take_cover [-> call_backup] -> attack against an armed enemy or, for an outnumbered officer,
-- a crowd. Cover is picked only when the attack cost makes it cheaper, so it needs no enemy_armed itself.
GOAP.RegisterAction('take_cover', {
	state = 'take_cover',
	always = true,
	pre = { has_enemy = true, armed = true, in_cover = false },
	effects = { in_cover = true },
	cost = 2,
})

GOAP.RegisterAction('call_backup', {
	state = 'call_backup',
	always = true,
	pre = { has_enemy = true, is_police = true, outnumbered = true, backup_called = false },
	effects = { backup_called = true },
	-- from cover first; in the open only when no cover is found (take_cover blocked)
	cost = function(ws) return Has(ws, 'in_cover') and 1 or 2 end,
})

-- A hurt gangster facing the police may give up (systems/arrest): it surrenders and the officer arrests it.
local ArrestModule
GOAP.RegisterAction('surrender', {
	state = 'arrest_surrender',
	always = true, -- no config weight; whether it happens is a roll per attempt (prepare)
	pre = { has_enemy = true, enemy_police = true, can_surrender = true, is_police = false },
	effects = { surrendered = true },
	cost = 1,
	prepare = function(actor)
		ArrestModule = ArrestModule or bgNPC.Modules.Get('player_arrest')
		if not ArrestModule or not GetConVar('bgn_arrest_mode'):GetBool() then return false end
		-- a failed roll blocks the action for BLOCK_TIME, so this is the chance per attempt, not a condition
		if not bgNPC.Util.Chance(SURRENDER_CHANCE) then return false end
		local npc = actor:GetNPC()
		local police = ArrestModule:FoundPoliceInRadius(npc)
		if not police then return false end

		ArrestModule:RemoveTarget(npc) -- a fresh arrest with this officer
		if not ArrestModule:Surrender(actor, police) then return false end
		actor:Voice('give_up')
		return true
	end,
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
	give_up = GOAP.Goal('give_up', { want = { surrendered = true } }),
	shelter = GOAP.Goal('shelter', { want = { door_held = true } }),
}

local function HideWhenWanted(ws) return Has(ws, 'wanted') and 20 or 0 end
local function ShelterWhenDesperate(ws)
	return Has(ws, 'desperate') and Has(ws, 'can_hold_door') and 30 or 0
end

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
	shelter = ShelterWhenDesperate,
	eliminate = function() return 6 end,
	survive = function(ws) return Has(ws, 'low_health') and 8 or 2 end,
	hide = HideWhenWanted,
	-- above hiding: the police chase a wanted gangster, and a hurt one may stop running
	give_up = function(ws) return Has(ws, 'can_surrender') and Has(ws, 'enemy_police') and 25 or 0 end,
})

GOAP.RegisterSet('citizen', {
	shelter = ShelterWhenDesperate,
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
		local chance = action.chance or (action.always and 1) or share[action.state]
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

	local A = GOAP.actions
	local fight = { A.attack, A.take_cover, A.call_backup }
	ws = bit.bor(F('has_enemy'), F('armed'), F('enemy_armed'), F('is_police'))
	plan = GOAP.Plan(ws, GOAP.goals.eliminate, fight)
	check(plan and #plan == 2 and plan[1] == A.take_cover and plan[2] == A.attack,
		'police vs one armed enemy: cover, attack, no backup')
	local crowd = bit.bor(F('has_enemy'), F('armed'), F('is_police'), F('outnumbered'))
	plan = GOAP.Plan(crowd, GOAP.goals.eliminate, fight)
	check(plan and #plan == 3 and plan[1] == A.take_cover and plan[2] == A.call_backup and plan[3] == A.attack,
		'outnumbered police: cover, backup, attack')
	plan = GOAP.Plan(crowd, GOAP.goals.eliminate, { A.attack, A.call_backup })
	check(plan and #plan == 2 and plan[1] == A.call_backup, 'outnumbered, no cover: backup in the open')
	plan = GOAP.Plan(bit.bor(crowd, F('backup_called'), F('in_cover')), GOAP.goals.eliminate, fight)
	check(plan and #plan == 1 and plan[1] == A.attack, 'in cover with backup: attack')
	plan = GOAP.Plan(bit.bor(F('has_enemy'), F('armed')), GOAP.goals.eliminate, fight)
	check(plan and #plan == 1 and plan[1] == A.attack, 'unarmed enemy: attack right away')

	ws = bit.bor(F('has_enemy'), F('armed'), F('wanted'))
	local gangster = GOAP.sets.gangster
	check(gangster.hide(ws) > gangster.eliminate(ws), 'a wanted gangster hides first')
	plan = GOAP.Plan(ws, GOAP.goals.hide, { GOAP.actions.attack, GOAP.actions.hide })
	check(plan and plan[1] == GOAP.actions.hide, 'hiding runs retreat')

	ws = bit.bor(F('has_enemy'), F('armed'), F('wanted'), F('can_surrender'), F('enemy_police'))
	check(gangster.give_up(ws) > gangster.hide(ws), 'a hurt gangster facing the police gives up before hiding')
	plan = GOAP.Plan(ws, GOAP.goals.give_up, { A.attack, A.hide, A.surrender })
	check(plan and #plan == 1 and plan[1] == A.surrender, 'giving up runs the surrender')

	ws = bit.bor(F('has_enemy'), F('desperate'), F('can_hold_door'))
	plan = GOAP.Plan(ws, GOAP.goals.shelter, { A.hold_door, A.flee })
	check(plan and #plan == 1 and plan[1] == A.hold_door, 'a desperate actor can close and hold an open door')
	check(citizen.shelter(ws) > citizen.survive(ws), 'an available door takes priority in a hopeless fight')
	check(GOAP.sets.police.shelter == nil, 'police have no door shelter goal')
	plan = GOAP.Plan(bit.bor(ws, F('is_police')), GOAP.goals.shelter, { A.hold_door })
	check(plan == nil, 'police cannot plan to hold a door')
	plan = GOAP.Plan(F('has_enemy'), GOAP.goals.shelter, { A.hold_door })
	check(plan == nil, 'a normal fight or absent open door cannot start holding')
	ws = bit.bor(F('has_enemy'), F('is_police'), F('enemy_bracing'), F('armed'))
	plan = GOAP.Plan(ws, GOAP.goals.eliminate, { A.attack, A.breach_door })
	check(plan and #plan == 1 and plan[1] == A.breach_door, 'police breach a held door before attacking')
	plan = GOAP.Plan(bit.bor(F('has_enemy'), F('enemy_bracing')), GOAP.goals.eliminate, { A.breach_door })
	check(plan == nil, 'a civilian cannot choose the police breach action')
end)
