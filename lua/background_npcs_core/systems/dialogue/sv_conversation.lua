--[[
	NPCs stop, face each other and talk (2-3 of them) with gestures: the "dialogue" state.
	Scripts: config/states/sh_conversations.lua, phrases: bgNPC.cfg.replics['conv_<id>'] (text + voice).

	A conversation: gather (walk to slots around a point, 8 s at most) -> talk (one phrase after another)
	-> the script's final action, or back to their business.
	A player standing close and looking at a conversation without a final action may interrupt it
	(INTERRUPT_CHANCE, once per conversation): they turn to the player and tell them off.

	Also here: fist fights ("brawl" state: no weapons, no deaths, the loser gives up and runs; police seeing
	it arrest both), and GTA-like staring: a player staring at someone standing still gets told off,
	then (civilians sometimes, gangsters always) beaten up. Police only warn.
--]]

local Chance = bgNPC.Util.Chance
local cvar_disable = GetConVar('bgn_disable_dialogues')

local Conv = { list = {} }
bgNPC.Conversation = Conv

local SEARCH_RADIUS = 400
local GATHER_TIME = 8
local INTERRUPT_CHANCE = 50
local INTERRUPT_DIST_SQR = 250 ^ 2
local STARE_DIST_SQR = 350 ^ 2
local STARE_STAGES = { 3, 7, 11 } -- seconds of staring: told off, warned, fight
local STARE_STATES = { idle = true, random_gesture = true }
local BRAWL_REACH_SQR = 60 ^ 2

local MOODS = {
	talk = { 'LineIdle01', 'LineIdle02', 'LineIdle03', 'LineIdle04', 'luggagewarn' },
	wave = { 'Wave_Close', 'Wave', 'wave_smg1' },
	angry = { 'Harassfront1', 'Harassfront2', 'plazathreat1', 'plazathreat2' },
	laugh = { 'cheer1', 'cheer2' },
	scared = { 'Fear_Reaction', 'scaredidle' },
	punch = { 'MeleeAttack01', 'swing', 'pushplayer', 'Harassfront1' },
}

-- Plays a random animation of the mood the model has (talk when it has none of them).
function Conv.Animate(actor, mood, time)
	local names = MOODS[mood] or MOODS.talk
	local start = math.random(#names)
	for i = 0, #names - 1 do
		local name = names[(start + i - 1) % #names + 1]
		if actor:IsValidSequence(name) then return actor:PlayStaticSequence(name, mood ~= 'punch', time) end
	end
	if mood ~= 'talk' and mood ~= 'punch' then return Conv.Animate(actor, 'talk', time) end
end

-- A phrase with text and voice; @return seconds it takes to say
function Conv.Say(actor, line_id, index)
	local lines = bgNPC.cfg.replics[line_id]
	if not lines or #lines == 0 then return 0 end
	index = index or math.random(#lines)
	-- shortcut: the clip length is only known on the client; 0.09 s a letter fits the Russian takes too
	local time = 1.2 + utf8.len(lines[index]) * 0.09
	actor:SayReplic(line_id, index, time)
	return time
end

local function Face(actor, pos)
	local npc = actor:GetNPC()
	if not IsValid(npc) then return end
	local ang = npc:GetAngles()
	npc:SetAngles(Angle(ang.x, (pos - npc:GetPos()):Angle().y, ang.z))
end

-- the line set of a faction: police_<id>, gangster_<id> (thieves too) or <default>
local function FactionLine(actor, id, default)
	if actor:HasTeam('police') then return 'police_' .. id end
	if actor:HasTeam('bandits') then return 'gangster_' .. id end
	return default or id
end

-- ---------------------------------------------------------------------------
-- Casting
-- ---------------------------------------------------------------------------

local function Fits(actor, spec)
	local actor_type = actor:GetType()
	if istable(spec) then return table.HasValue(spec, actor_type) end
	return spec == actor_type
end

local function IsFree(actor)
	return actor:IsAlive() and not actor:InVehicle() and not actor.conversation and actor:EqualStateGroup('calm')
		and not actor:HasState('scenic_npc')
end

-- @return table cast { [role] = actor } or nil
local function Cast(script, initiator, candidates)
	local lines = bgNPC.cfg.replics['conv_' .. script.id]
	if not lines or #lines ~= #script.lines then return end -- a language file out of step with the script

	for role, spec in ipairs(script.roles) do
		if Fits(initiator, spec) then
			local cast, used, count = { [role] = initiator }, { [initiator] = true }, 1
			for other, other_spec in ipairs(script.roles) do
				if not cast[other] then
					for _, candidate in ipairs(candidates) do
						if not used[candidate] and Fits(candidate, other_spec) then
							cast[other], used[candidate], count = candidate, true, count + 1
							break
						end
					end
				end
			end
			if count == #script.roles then return cast end
		end
	end
end

-- @return script, cast: a weighted random script these actors can play
function Conv.Pick(initiator, candidates)
	local scripts = table.Copy(bgNPC.cfg.conversations or {})
	while #scripts > 0 do
		local total = 0
		for _, script in ipairs(scripts) do total = total + (script.chance or 10) end
		local roll, index = math.random() * total, #scripts
		for i, script in ipairs(scripts) do
			roll = roll - (script.chance or 10)
			if roll <= 0 then index = i break end
		end
		local script = table.remove(scripts, index)
		local cast = Cast(script, initiator, candidates)
		if cast then return script, cast end
	end
end

-- ---------------------------------------------------------------------------
-- Conversation
-- ---------------------------------------------------------------------------

-- Starts a conversation of the initiator with the actors around. The initiator's own "dialogue" state is set
-- by the caller (the state's validator). @return boolean
function Conv.TryStart(initiator)
	if cvar_disable:GetBool() or initiator.conversation then return false end
	local npc = initiator:GetNPC()
	local candidates = {}
	for _, actor in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), SEARCH_RADIUS)) do
		if actor ~= initiator and IsFree(actor) and bgNPC.Vision.HasLineOfSight(npc, actor:GetNPC()) then
			candidates[#candidates + 1] = actor
		end
	end
	if #candidates == 0 then return false end
	table.Shuffle(candidates)

	local script, cast = Conv.Pick(initiator, candidates)
	if not script then return false end

	local center = Vector()
	for _, actor in ipairs(cast) do center:Add(actor:GetPos()) end
	center:Div(#cast)

	local conv = { script = script, cast = cast, phase = 'gather', line = 0, next_time = CurTime() + GATHER_TIME, slots = {} }
	local radius = #cast == 2 and 38 or 48
	local turn = math.Rand(0, math.pi * 2)
	for i in ipairs(cast) do
		local a = turn + (i / #cast) * math.pi * 2
		conv.slots[i] = center + Vector(math.cos(a), math.sin(a), 0) * radius
	end

	Conv.list[#Conv.list + 1] = conv
	for _, actor in ipairs(cast) do actor.conversation = conv end
	for _, actor in ipairs(cast) do
		if actor ~= initiator then actor:SetState('dialogue', nil, true) end
	end
	return true
end

local FINALS = {}

function FINALS.fight(cast)
	Conv.BrawlStart(cast[1], cast[2]:GetNPC())
end

function FINALS.attack(cast)
	cast[2]:AddEnemy(cast[1]:GetNPC())
	cast[2]:SetState('defense', nil, true)
	cast[1]:AddEnemy(cast[2]:GetNPC())
	cast[1]:SetState('defense', nil, true)
end

function FINALS.flee(cast)
	local hunter, prey = cast[1], cast[2]
	if hunter:HasTeam('police') then
		if Chance(50) then return Conv.ArrestAll(hunter, { prey:GetNPC() }) end
		hunter:AddEnemy(prey:GetNPC())
		hunter:SetState('defense', nil, true)
		hunter:Voice('police_combat')
	end
	prey:AddEnemy(hunter:GetNPC(), 'fear')
	prey:SetState('fear', nil, true)
end

function FINALS.run_off(cast)
	cast[1]:SetState('walk', {
		schedule = 'run', timeToResetRunMovementType = CurTime() + 20, updateMovementTypeDelay = CurTime() + 20,
	}, true)
end

-- @param final boolean run the script's final action
function Conv.Finish(conv, final)
	table.RemoveByValue(Conv.list, conv)
	for _, actor in ipairs(conv.cast) do
		if actor.conversation == conv then actor.conversation = nil end
	end

	local action = final and conv.script.final and FINALS[conv.script.final]
	local alive = true
	for _, actor in ipairs(conv.cast) do alive = alive and actor:IsAlive() end
	if action and alive then action(conv.cast) end

	for _, actor in ipairs(conv.cast) do
		if actor:IsAlive() and actor:HasState('dialogue') then actor:RandomState() end
	end
end

function Conv.Interrupt(conv, ply)
	conv.phase, conv.react_target, conv.next_time = 'react', ply, CurTime() + 4
	local speaker = table.Random(conv.cast)
	for _, actor in ipairs(conv.cast) do actor:StopWalk() end
	Conv.Animate(speaker, 'angry', 3)
	Conv.Say(speaker, FactionLine(speaker, 'interrupt', 'conv_interrupt'))
end

local function IsIntact(conv)
	for _, actor in ipairs(conv.cast) do
		if not actor:IsAlive() or actor.conversation ~= conv or not actor:HasState('dialogue') then return false end
	end
	return true
end

local function Tick(conv)
	if not IsIntact(conv) then return Conv.Finish(conv, false) end
	local now, cast = CurTime(), conv.cast

	if conv.phase == 'gather' then
		local ready = true
		for i, actor in ipairs(cast) do
			if actor:GetPos():DistToSqr(conv.slots[i]) > 40 ^ 2 then
				ready = false
				if not actor.conv_walk or actor.conv_walk < now then
					actor:WalkToPos(conv.slots[i])
					actor.conv_walk = now + 2
				end
			end
		end
		if ready or conv.next_time < now then
			for _, actor in ipairs(cast) do actor:StopWalk() end
			conv.phase, conv.next_time = 'talk', now + 0.5
		end
		return
	end

	if conv.phase == 'react' then
		if not IsValid(conv.react_target) or conv.next_time < now then return Conv.Finish(conv, false) end
		for _, actor in ipairs(cast) do Face(actor, conv.react_target:GetPos()) end
		return
	end

	-- talk: the speaker faces the others, the others face the speaker
	local speaker = conv.speaker
	if conv.next_time < now then
		conv.line = conv.line + 1
		local line = conv.script.lines[conv.line]
		if not line then return Conv.Finish(conv, true) end
		speaker = cast[line[1]]
		conv.speaker = speaker
		local time = Conv.Say(speaker, 'conv_' .. conv.script.id, conv.line)
		Conv.Animate(speaker, line[2] or 'talk', time)
		conv.next_time = now + time + 0.4
	end
	if not speaker then return end -- the pause before the first phrase

	local center = Vector()
	for _, actor in ipairs(cast) do
		if actor ~= speaker then center:Add(actor:GetPos()) end
	end
	center:Div(#cast - 1)
	for _, actor in ipairs(cast) do
		Face(actor, actor == speaker and center or speaker:GetPos())
		if actor:IsSequenceFinished() then actor:GetBody():HoldStill() end
	end
end

timer.Create('BGN_Conversations', 0.2, 0, function()
	for i = #Conv.list, 1, -1 do
		local conv = Conv.list[i]
		if conv then Tick(conv) end
	end
end)

hook.Add('PostCleanupMap', 'BGN_Conversations', function() Conv.list = {} end)

-- ---------------------------------------------------------------------------
-- Arrests and fist fights
-- ---------------------------------------------------------------------------

-- The police officer arrests all of them one after another; NPCs give up and wait.
function Conv.ArrestAll(police, targets)
	local ArrestModule = bgNPC.Modules.Get('player_arrest')
	if police:InVehicle() then police:ExitVehicle() end
	police:RemoveAllTargets()

	for _, ent in ipairs(targets) do
		if IsValid(ent) then
			ArrestModule:RemoveTarget(ent)
			ArrestModule:AddTarget(ent, police)
			police:AddTarget(ent)
			local actor = bgNPC.Actors.Get(ent)
			if actor then
				actor:RemoveAllEnemies()
				actor:RemoveAllTargets()
				actor:AddTarget(police:GetNPC())
				actor:SetState('arrest_surrender', nil, true)
			end
		end
	end
	-- after the targets: the arrest state shoots an NPC target that isn't surrendering
	police:SetState('arrest', nil, true)
end

-- @param enemy entity an actor's NPC or a player
function Conv.BrawlStart(actor, enemy)
	actor:SetState('brawl', { enemy = enemy }, true)
	local other = bgNPC.Actors.Get(enemy)
	if other then other:SetState('brawl', { enemy = actor:GetNPC() }, true) end
	Conv.Say(actor, 'brawl_start')
end

local function BrawlStop(actor)
	actor:StopWalk()
	actor:RandomState()
end

local function PoliceSeeing(actor, enemy)
	local ArrestModule = bgNPC.Modules.Get('player_arrest')
	if not GetConVar('bgn_arrest_mode'):GetBool() then return end
	for _, ent in ipairs({ actor:GetNPC(), enemy }) do
		local police = ArrestModule:FoundPoliceInRadius(ent)
		if police and police:EqualStateGroup('calm') and not police:InVehicle() then return police end
	end
end

-- No weapons and no real damage events: the hits change health directly, so nobody calls it a murder.
bgNPC.States.Register('brawl', 'assault', {
	start = function(actor, state, data)
		data.until_time = CurTime() + 45
		data.next_hit = CurTime() + math.Rand(0.5, 1.2)
		data.next_police = 0
	end,
	update = function(actor, state, data)
		local enemy, npc, now = data.enemy, actor:GetNPC(), CurTime()
		if not IsValid(enemy) or enemy:Health() <= 0 or now > data.until_time
			or npc:GetPos():DistToSqr(enemy:GetPos()) > 800 ^ 2
		then
			return BrawlStop(actor)
		end

		local other = bgNPC.Actors.Get(enemy)
		if other and not other:HasState('brawl') then return BrawlStop(actor) end

		if data.next_police < now then
			data.next_police = now + 1
			local police = PoliceSeeing(actor, enemy)
			if police then
				Conv.Say(police, 'police_brawl')
				return Conv.ArrestAll(police, { npc, enemy })
			end
		end

		if npc:GetPos():DistToSqr(enemy:GetPos()) > BRAWL_REACH_SQR then
			actor:WalkToTarget(enemy, 'run')
			return
		end

		actor:StopWalk()
		Face(actor, enemy:GetPos())
		if data.next_hit > now then return end
		data.next_hit = now + math.Rand(0.9, 1.6)

		Conv.Animate(actor, 'punch')
		npc:EmitSound('Flesh.ImpactHard')
		local hp = enemy:Health() - math.random(4, 9)

		if enemy:IsPlayer() then
			if hp <= 15 then -- beaten, not killed
				Conv.Say(actor, 'brawl_win')
				return BrawlStop(actor)
			end
			enemy:SetHealth(hp)
			enemy:ViewPunch(Angle(-6, math.random(-4, 4), 0))
			return
		end

		enemy:SetHealth(math.max(hp, 1))
		if other and hp <= enemy:GetMaxHealth() * 0.35 then -- gives up and runs
			Conv.Say(actor, 'brawl_win')
			Conv.Say(other, 'brawl_lose')
			BrawlStop(actor)
			other:AddEnemy(npc, 'fear')
			other:SetState('fear', nil, true)
		end
	end,
})

-- ---------------------------------------------------------------------------
-- Players looking at actors
-- ---------------------------------------------------------------------------

local function Stare(ply, actor, time)
	if not actor:IsAlive() or not STARE_STATES[actor:GetState()] then actor.stare = nil return end
	if ply:GetPos():DistToSqr(actor:GetPos()) > STARE_DIST_SQR then return end

	local stare = actor.stare
	if not stare or stare.ply ~= ply or time < STARE_STAGES[1] - 1 then
		stare = { ply = ply, stage = 0 }
		actor.stare = stare
	end

	local stage = stare.stage + 1
	if stage > 1 then Face(actor, ply:GetPos()) end
	if not STARE_STAGES[stage] or time < STARE_STAGES[stage] then return end
	stare.stage = stage
	Face(actor, ply:GetPos())
	actor:StopWalk()

	if stage == 3 then
		actor.stare = nil
		if actor:HasTeam('police') then return end
		if actor:HasTeam('bandits') or Chance(50) then return Conv.BrawlStart(actor, ply) end
		return actor:SetState('walk', nil, true) -- walks away
	end

	Conv.Animate(actor, stage == 1 and 'talk' or 'angry', 2.5)
	Conv.Say(actor, FactionLine(actor, 'stare_' .. stage))
end

hook.Add('BGN_PlayerLookAtObject', 'BGN_Conversations', function(ply, ent, time)
	local actor = bgNPC.Actors.Get(ent)
	if not actor then return end

	local conv = actor.conversation
	if not conv then return Stare(ply, actor, time) end
	if conv.phase ~= 'talk' or conv.script.final or conv.interrupt_tried or time < 2 then return end
	if ply:GetPos():DistToSqr(actor:GetPos()) > INTERRUPT_DIST_SQR then return end
	conv.interrupt_tried = true
	if Chance(INTERRUPT_CHANCE) then Conv.Interrupt(conv, ply) end
end)

bgNPC.Test.Add('conversations.scripts', function(check)
	for _, script in ipairs(bgNPC.cfg.conversations or {}) do
		local lines = bgNPC.cfg.replics['conv_' .. script.id]
		check(lines and #lines == #script.lines, 'conv_' .. script.id .. ': phrases match the script lines')
		check(#script.roles >= 2 and #script.roles <= 3, script.id .. ': 2-3 roles')
		check(not script.final or FINALS[script.final], script.id .. ': known final')
		for _, line in ipairs(script.lines) do
			check(script.roles[line[1]] ~= nil, script.id .. ': speaker has a role')
		end
	end
end)

bgNPC.Test.Add('conversations.cast', function(check)
	local function Fake(actor_type) return { GetType = function() return actor_type end } end
	local police, thief, citizen = Fake('police'), Fake('thief'), Fake('citizen')
	local script = { id = 'police_thief', roles = { 'police', 'thief' }, lines = bgNPC.cfg.replics['conv_police_thief'] }
	local cast = Cast(script, thief, { citizen, police })
	check(cast and cast[1] == police and cast[2] == thief, 'the initiator takes its own role, a candidate the other')
	check(Cast(script, citizen, { police, thief }) == nil, 'no role for the initiator: no conversation')
	check(Cast(script, police, { citizen }) == nil, 'a role nobody can take: no conversation')
end)
