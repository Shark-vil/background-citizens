--[[
	NextBotBody: drives a bgn_nextbot entity (lua/entities/bgn_nextbot.lua).
	The bot paths over the NavMesh by itself, so the actor gives it the goal, not node by node
	(see bgNPC.Nav.BodyPathsItself).

	Body choice: "bgn_actor_body auto|npc|nextbot". NextBot needs a loaded NavMesh and an HL2 class
	(npc_citizen, npc_metropolice, npc_combine_s); "auto" uses it whenever both are true.
--]]

local Body = bgNPC.Body

local NextBotBody = bgNPC.Class('BGN_NextBotBody', Body)
bgNPC.NextBotBody = NextBotBody

NextBotBody.CLASS = 'bgn_nextbot'
NextBotBody.SUPPORTED_CLASSES = { npc_citizen = true, npc_metropolice = true, npc_combine_s = true }

local MOVE_AWAY_DISTANCE = 300
local cvar_body = CreateConVar('bgn_actor_body', 'auto', { FCVAR_ARCHIVE },
	'Background NPCs: actor body (auto - NextBot on NavMesh maps, npc, nextbot)')

function NextBotBody:Init(actor, ent)
	Body.Init(self, actor, ent)
	ent:BGN_ResetHull() -- the spawner may have changed the model after Initialize
end

function NextBotBody:IsNextBot() return true end

function NextBotBody:MoveTo(pos, run)
	if IsValid(self.ent) then self.ent:BGN_MoveTo(pos, run) end
end

function NextBotBody:StopMoving()
	if IsValid(self.ent) then self.ent:BGN_Stop() end
end

function NextBotBody:IsMoving()
	return IsValid(self.ent) and self.ent:BGN_IsMoving()
end

function NextBotBody:MoveAwayFromEnemy()
	local ent, enemy = self.ent, self:GetEnemy()
	if not IsValid(ent) or not IsValid(enemy) then return end
	local away = (ent:GetPos() - enemy:GetPos()):GetNormalized()
	away.z = 0
	ent:BGN_MoveTo(ent:GetPos() + away * MOVE_AWAY_DISTANCE, true)
end

function NextBotBody:Cower()
	local ent = self.ent
	if not IsValid(ent) then return end
	ent:BGN_PlaySequence(ent:SelectWeightedSequence(ACT_COWER))
end

-- Maps the schedules the addon uses; the rest has no NextBot meaning.
function NextBotBody:RunSchedule(schedule)
	local ent = self.ent
	if not IsValid(ent) then return end
	if schedule == SCHED_MOVE_AWAY_FROM_ENEMY or schedule == SCHED_RUN_FROM_ENEMY then
		self:MoveAwayFromEnemy()
	elseif schedule == SCHED_IDLE_STAND or schedule == SCHED_NONE then
		ent:BGN_Stop()
	end
end

function NextBotBody:ClearSchedule()
	self:StopMoving()
end

function NextBotBody:IsBusyInCombat()
	return IsValid(self.ent) and self.ent:BGN_IsBusy()
end

-- Dispositions: the bot keeps its own table; an HL2 NPC that the bot hates is told to hate it back,
-- otherwise HL2 NPCs ignore NextBots.
function NextBotBody:SetDisposition(ent, disposition)
	if not IsValid(ent) then return end
	self.dispositions = self.dispositions or setmetatable({}, { __mode = 'k' })
	self.dispositions[ent] = disposition
	if disposition == D_HT and ent:IsNPC() and IsValid(self.ent) then
		ent:AddEntityRelationship(self.ent, D_HT, 99)
	end
end

function NextBotBody:GetDisposition(ent)
	return self.dispositions and self.dispositions[ent] or D_NU
end

function NextBotBody:SetEnemy(ent)
	if IsValid(self.ent) then self.ent:BGN_SetEnemy(ent) end
	if IsValid(ent) then self.enemy_seen = CurTime() end
end

function NextBotBody:GetEnemy()
	return IsValid(self.ent) and self.ent:BGN_GetEnemy() or NULL
end

function NextBotBody:GetEnemyLastTimeSeen(ent)
	local bot = self.ent
	if IsValid(bot) and IsValid(ent) and bot:CanSeeEnemy(ent) then self.enemy_seen = CurTime() end
	return self.enemy_seen or 0
end

function NextBotBody:SetAlertLevel(level)
	if IsValid(self.ent) then self.ent:BGN_SetAlert(level) end
end

function NextBotBody:GiveWeapon(weapon_class)
	if not IsValid(self.ent) then return NULL end
	return self.ent:Give(weapon_class)
end

function NextBotBody:GetActiveWeapon()
	return IsValid(self.ent) and self.ent:GetActiveWeapon() or NULL
end

function NextBotBody:RemoveActiveWeapon()
	if IsValid(self.ent) then self.ent:BGN_RemoveWeapon() end
end

function NextBotBody:PlaySequence(sequence_id)
	return IsValid(self.ent) and self.ent:BGN_PlaySequence(sequence_id)
end

function NextBotBody:StopSequence()
	if IsValid(self.ent) then self.ent:BGN_StopSequence() end
end

-- @return string entity class to create for an actor of this NPC class
function NextBotBody.ResolveClass(npc_class)
	local mode = cvar_body:GetString()
	if mode == 'npc' or not NextBotBody.SUPPORTED_CLASSES[npc_class] then return npc_class end
	if not navmesh.IsLoaded() then return npc_class end
	return NextBotBody.CLASS
end
