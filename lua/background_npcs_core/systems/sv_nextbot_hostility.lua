--[[
	Regular HL2 NPCs have no relationship with a NextBot body: the engine only knows classes of NPCs and players,
	so an "Enemy Rebel" walks past a nextbot actor. The NPC gets the relationship it has with the actor's original
	NPC class, measured on a hidden probe NPC of that class (works for modded NPC classes too). NPC senses see the
	bot because it carries FL_OBJECT (entities/bgn_nextbot.lua); without it an NPC only faces it, never shoots.
--]]

local PERIOD = 1
local RANGE_SQR = 2500 ^ 2
local cvar_ignore_another_npc = GetConVar('bgn_ignore_another_npc')
local probes = {}

-- shortcut: the probe sits at the first nav area; a map without a NavMesh has no nextbot actors anyway.
local function Probe(class)
	local probe = probes[class]
	if IsValid(probe) then return probe end

	local area = navmesh.GetAllNavAreas()[1]
	probe = ents.Create(class)
	if not IsValid(probe) then return end
	probe.bgn_probe = true
	probe:SetPos(area and area:GetCenter() or vector_origin)
	probe:Spawn()
	probe:SetNoDraw(true)
	probe:SetNotSolid(true)
	probe:AddFlags(FL_NOTARGET) -- hostile NPCs must not hunt the hidden probe
	probe:AddEFlags(EFL_NO_THINK_FUNCTION)
	probes[class] = probe
	return probe
end

timer.Create('BGN_Timer_NextBotHostility', PERIOD, 0, function()
	if bgNPC.Modes.IsPeaceful() or cvar_ignore_another_npc:GetBool() then return end

	local bots = {}
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local body = actor:IsAlive() and actor:GetNPC()
		if IsValid(body) and body:IsNextBot() and not actor:InVehicle() then bots[#bots + 1] = actor end
	end
	if #bots == 0 then return end

	for _, npc in ipairs(ents.GetAll()) do
		if IsValid(npc) and npc:IsNPC() and not npc.isBgnActor and not npc.bgn_probe and npc:Health() > 0 then
			local pos = npc:GetPos()
			for _, actor in ipairs(bots) do
				local body = actor:GetNPC()
				-- already hated: the actor fights this NPC (NextBotBody:SetDisposition) or an earlier pass.
				-- The NPC's own senses do the rest: the bot carries FL_OBJECT (entities/bgn_nextbot.lua).
				if pos:DistToSqr(body:GetPos()) <= RANGE_SQR and npc:Disposition(body) ~= D_HT then
					local probe = Probe(actor.class)
					if probe and npc:Disposition(probe) == D_HT then npc:AddEntityRelationship(body, D_HT, 100) end
				end
			end
		end
	end
end)
