--[[
	Brain: decides what an actor does. Called by the actor update loop (actor/update/sv_actor_update.lua).

		FSMBrain   (brain/fsm)   - the classic state machine, default for unarmed civilians
		GOAPBrain  (brain/goap)  - goal oriented planner for combat actors

	Choice: actor config "brain = 'fsm' | 'goap'", overridden by the cvar "bgn_brain auto|fsm|goap".
	In "auto" an actor without an explicit config value gets GOAP when it can carry a weapon.
--]]

local Brain = bgNPC.Class('BGN_Brain')
bgNPC.Brain = Brain

local cvar_brain = CreateConVar('bgn_brain', 'auto', { FCVAR_ARCHIVE },
	'Background NPCs: actor brain type (auto, fsm, goap)')

function Brain:Init(actor)
	self.actor = actor
end

-- Called periodically (the period depends on the actor LOD).
function Brain:Update() end

-- Events from the world: 'damaged', 'enemy_added', 'enemies_cleared', 'state_changed', ...
function Brain:OnEvent(name, ...) end

-- The actor was removed or the brain replaced.
function Brain:Stop() end

local registry = Brain.registry or {}
Brain.registry = registry

-- @param name string brain name used in configs and the cvar
function Brain.Register(name, cls)
	registry[name] = cls
end

local function WantsGOAP(data)
	return istable(data.weapons) and #data.weapons ~= 0
end

-- @return string brain name for the actor
function Brain.Resolve(actor)
	local data = actor:GetData()
	local forced = cvar_brain:GetString()

	if forced == 'fsm' or forced == 'goap' then return forced end
	if isstring(data.brain) and registry[data.brain] then return data.brain end

	return WantsGOAP(data) and registry.goap and 'goap' or 'fsm'
end

function Brain.For(actor)
	local cls = registry[Brain.Resolve(actor)] or registry.fsm
	return cls(actor)
end

-- Rebuilds brains of existing actors when the cvar changes.
cvars.AddChangeCallback('bgn_brain', function()
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		if actor.brain then actor.brain:Stop() end
		actor.brain = Brain.For(actor)
	end
end, 'bgn_brain_rebuild')
