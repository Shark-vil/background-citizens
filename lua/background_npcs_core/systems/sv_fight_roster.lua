--[[
	Gang fights have a roster. The first member of a gang who takes an enemy (is shot at, sees a crime) starts the fight
	of his gang against that enemy: the roster is formed right then, from the initiator and the nearest living members
	of the SAME gang within RADIUS, each of them joining with the chance "bgn_gang_help_chance" percent, at most
	MIN_SIZE..MAX_SIZE (random per roster, the initiator counts). Every other member of the gang is refused that enemy
	(BGN_AddActorEnemy) and ignores the call for help (Actor:GetReactionForProtect), so a fight no longer grows to
	the whole crowd. The police and the player fight the roster only. Members of other gangs never help: they are
	not teammates (Actor:HasTeam), a gang war between them starts by chance (bgn_gang_war_chance) and, once the police or
	a player step in, everybody fights everybody within their own rosters.
	Actors that are not in a gang (police, civilians) are not touched.
--]]

local Roster = {}
bgNPC.Roster = Roster

local RADIUS = 1000
local MIN_SIZE, MAX_SIZE = 2, 6
local WAR_PERIOD = 10
local WAR_RADIUS = 700
local END_AFTER = 10 -- seconds without a living member that still fights the enemy
local cvar_help = GetConVar('bgn_gang_help_chance')
local cvar_war = GetConVar('bgn_gang_war_chance')

local rosters = setmetatable({}, { __mode = 'k' }) -- [enemy] = { [gang] = roster }

local function GangOf(actor)
	return actor.data and actor.data.gang
end

local function Join(roster, member)
	roster.members[member] = true
	roster.size = roster.size + 1
end

-- @return table the roster of the gang against the enemy, formed around the initiator
local function Form(initiator, gang, enemy)
	local roster = { members = {}, size = 0, limit = math.random(MIN_SIZE, MAX_SIZE), last = CurTime() }
	Join(roster, initiator)
	rosters[enemy] = rosters[enemy] or {}
	rosters[enemy][gang] = roster

	local pos = initiator:GetNPC():GetPos()
	local near = {}
	for _, other in ipairs(bgNPC.Actors.GetInRadius(pos, RADIUS)) do
		if other ~= initiator and other:IsAlive() and not other:InVehicle() and GangOf(other) == gang then
			near[#near + 1] = { actor = other, dist = other:GetNPC():GetPos():DistToSqr(pos) }
		end
	end
	table.sort(near, function(a, b) return a.dist < b.dist end)

	local chance = cvar_help:GetFloat()
	local helpers = {}
	for _, entry in ipairs(near) do
		if roster.size >= roster.limit then break end
		if math.random() * 100 < chance then
			Join(roster, entry.actor)
			helpers[#helpers + 1] = entry.actor
		end
	end

	-- the chosen ones come at once; they are members now, so the refusal below lets them through
	for _, helper in ipairs(helpers) do
		helper:AddEnemy(enemy)
		if helper:EqualStateGroup('calm') then helper:SetState('defense') end
	end
	return roster
end

-- @return table|nil the gang's roster against the enemy
function Roster.Get(gang, enemy)
	return rosters[enemy] and rosters[enemy][gang]
end

-- @return boolean the actor may fight this enemy as a member of its gang's roster (always true for non-gang actors)
function Roster.IsMember(actor, enemy)
	local gang = GangOf(actor)
	if not gang then return true end
	local roster = Roster.Get(gang, enemy)
	return roster ~= nil and roster.members[actor] == true
end

hook.Add('BGN_AddActorEnemy', 'BGN_FightRoster', function(actor, enemy)
	local gang = GangOf(actor)
	if not gang then return end
	local roster = Roster.Get(gang, enemy)
	if not roster then
		Form(actor, gang, enemy)
		return
	end
	-- self-defence: an actor that was just hit by this enemy fights back whatever the roster says
	if not roster.members[actor] and actor.last_attacker == enemy and CurTime() - (actor.last_attacked_at or 0) < 2 then
		Join(roster, actor)
	end
	if roster.members[actor] then
		roster.last = CurTime()
		return
	end
	return true
end)

timer.Create('BGN_FightRosterCleanup', 5, 0, function()
	local now = CurTime()
	for enemy, by_gang in pairs(rosters) do
		for gang, roster in pairs(by_gang) do
			local fighting = IsValid(enemy) and enemy:Health() > 0
			if fighting then
				fighting = false
				for member in pairs(roster.members) do
					if member:IsAlive() and member:HasEnemy(enemy) then fighting = true break end
				end
			end
			if fighting then roster.last = now elseif now - roster.last > END_AFTER then by_gang[gang] = nil end
		end
		if next(by_gang) == nil then rosters[enemy] = nil end
	end
end)

-- Two gangs near each other sometimes go for each other's throats.
timer.Create('BGN_GangWar', WAR_PERIOD, 0, function()
	local chance = cvar_war:GetFloat()
	if chance <= 0 or bgNPC.Modes.IsPeaceful() then return end

	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local gang = GangOf(actor)
		if gang and actor:IsAlive() and not actor:InVehicle() and actor:HasNoEnemies() and actor:EqualStateGroup('calm')
			and math.random() * 100 < chance
		then
			local npc = actor:GetNPC()
			for _, other in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), WAR_RADIUS)) do
				local other_gang = GangOf(other)
				if other_gang and other_gang ~= gang and other:IsAlive() and not other:InVehicle()
					and other:EqualStateGroup('calm') and bgNPC.Vision.HasLineOfSight(npc, other:GetNPC())
				then
					actor:AddEnemy(other:GetNPC())
					other:AddEnemy(npc)
					actor:SetState('defense')
					other:SetState('defense')
					break
				end
			end
		end
	end
end)
