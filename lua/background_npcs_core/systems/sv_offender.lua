--[[
	Offender: a civilian who kills a resident or an officer stops being a resident. Only this actor's team changes
	(actor.data is a copy of the config), so the team immunity no longer covers him: the police and the residents
	treat him as an enemy (wanted list, arrest, defense, fear). He runs from them or, near an officer, may surrender.
--]]

local TEAM = 'offenders'
local SURRENDER_CHANCE = 40
local FLEE_RADIUS = 1500

local WantedModule = bgNPC.Modules.Get('wanted')
local ArrestModule = bgNPC.Modules.Get('player_arrest')

local function MakeOffender(actor)
	local team = {}
	for _, name in ipairs(actor.data.team or {}) do
		if name ~= 'residents' then team[#team + 1] = name end
	end
	team[#team + 1] = TEAM
	actor:SetTeam(team)
end

-- Same chain as the arrest in sv_arrest.lua: the officer arrests, the offender gives up.
local function Surrender(offender, police)
	local npc = offender:GetNPC()
	if not ArrestModule:AddTarget(npc, police) then return false end

	if police:InVehicle() then police:ExitVehicle() end
	offender:RemoveAllTargets()
	offender:AddTarget(police:GetNPC())
	offender:SetState('arrest_surrender', nil, true)

	police:RemoveAllTargets()
	police:AddTarget(npc)
	police:SetState('arrest', nil, true)
	return true
end

local function RunAway(offender)
	local npc = offender:GetNPC()
	local nearest, nearest_dist
	for _, actor in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), FLEE_RADIUS)) do
		if actor ~= offender and actor:IsAlive() and actor:HasTeam('residents') then
			local dist = actor:GetNPC():GetPos():DistToSqr(npc:GetPos())
			if not nearest_dist or dist < nearest_dist then nearest, nearest_dist = actor, dist end
		end
	end
	if not nearest then return end

	offender:RemoveAllTargets()
	offender:AddEnemy(nearest:GetNPC(), 'fear')
	offender:SetState('fear', nil, true)
end

hook.Add('BGN_OnKilledActor', 'BGN_Offender', function(victim, attacker)
	if bgNPC.Modes.IsPeaceful() or not IsValid(attacker) or attacker == victim:GetNPC() then return end

	local offender = bgNPC.Actors.Get(attacker)
	if not offender or not offender:IsAlive() or not offender:IsCivilian() or not victim:HasTeam('residents') then return end

	MakeOffender(offender)

	-- nobody saw it: no manhunt, but the immunity is gone
	if not GetConVar('bgn_enable_wanted_mode'):GetBool() or not bgNPC.Vision.AnyActorSees(attacker, victim) then return end
	WantedModule:AddWanted(attacker)

	local police = ArrestModule:FoundPoliceInRadius(attacker)
	if police and GetConVar('bgn_arrest_mode'):GetBool() and bgNPC.Util.Chance(SURRENDER_CHANCE) and Surrender(offender, police) then
		return
	end
	RunAway(offender)
end)
