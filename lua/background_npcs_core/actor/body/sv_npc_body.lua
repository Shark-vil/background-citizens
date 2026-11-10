--[[
	NPCBody: HL2 NPC driven through engine schedules.
--]]

local NPCBody = bgNPC.Class('BGN_NPCBody', bgNPC.Body)
bgNPC.NPCBody = NPCBody

-- Schedules the engine runs while the NPC is fighting. Movement must not interrupt them,
-- otherwise the NPC never gets to shoot or reload.
local COMBAT_SCHEDULES = {}
for _, schedule in ipairs({
	SCHED_HIDE_AND_RELOAD, SCHED_RELOAD, SCHED_ESTABLISH_LINE_OF_FIRE,
	SCHED_RANGE_ATTACK1, SCHED_RANGE_ATTACK2, SCHED_SPECIAL_ATTACK1, SCHED_SPECIAL_ATTACK2,
	SCHED_MELEE_ATTACK1, SCHED_MELEE_ATTACK2, SCHED_SLEEP, SCHED_NPC_FREEZE,
}) do
	if schedule then COMBAT_SCHEDULES[schedule] = true end
end

local ALERT_STATES = {
	idle = NPC_STATE_IDLE,
	alert = NPC_STATE_ALERT,
	combat = NPC_STATE_COMBAT,
}

local CAPABILITIES = CAP_DUCK + CAP_MOVE_SHOOT + CAP_USE + CAP_TURN_HEAD + CAP_SQUAD + CAP_AIM_GUN
local DOOR_CAPABILITIES = CAP_AUTO_DOORS + CAP_OPEN_DOORS -- "bgn_npc_open_doors" (actor/events/sv_open_door.lua)

function NPCBody:Init(actor, ent)
	bgNPC.Body.Init(self, actor, ent)
	ent:CapabilitiesAdd(CAPABILITIES)
	if GetConVar('bgn_npc_open_doors'):GetBool() then ent:CapabilitiesAdd(DOOR_CAPABILITIES) end
end

function NPCBody:IsNPC() return true end

function NPCBody:IsDead()
	local ent = self.ent
	return not IsValid(ent) or ent:Health() <= 0 or ent:IsCurrentSchedule(SCHED_DIE)
end

function NPCBody:RunSchedule(schedule)
	local ent = self.ent
	if not IsValid(ent) then return end
	ent:SetSchedule(schedule)
	self.actor.npc_schedule = ent:GetCurrentSchedule()
	self.actor.npc_state = ent:GetNPCState()
end

function NPCBody:ClearSchedule()
	local ent = self.ent
	if not IsValid(ent) then return end
	ent:SetNPCState(NPC_STATE_IDLE)
	ent:ClearSchedule()
	self.actor.npc_schedule = ent:GetCurrentSchedule()
	self.actor.npc_state = ent:GetNPCState()
end

function NPCBody:IsBusyInCombat()
	local ent = self.ent
	return IsValid(ent) and COMBAT_SCHEDULES[ent:GetCurrentSchedule()] == true
end

function NPCBody:MoveTo(pos, run)
	local ent = self.ent
	if not IsValid(ent) or self:IsBusyInCombat() then return end
	local schedule = run and SCHED_FORCED_GO_RUN or SCHED_FORCED_GO
	if self.moveGoal and self.moveGoal:DistToSqr(pos) < 1 and ent:IsCurrentSchedule(schedule) then return end
	self.moveGoal = pos
	ent:SetLastPosition(pos)
	self:RunSchedule(schedule)
end

function NPCBody:StopMoving()
	self:ClearSchedule()
end

function NPCBody:IsMoving()
	return IsValid(self.ent) and self.ent:IsMoving()
end

function NPCBody:HoldStill()
	local ent = self.ent
	if not IsValid(ent) then return end
	ent:SetNPCState(NPC_STATE_SCRIPT)
	self:RunSchedule(SCHED_SLEEP)
end

function NPCBody:MoveAwayFromEnemy()
	self:RunSchedule(SCHED_MOVE_AWAY_FROM_ENEMY)
end

function NPCBody:Cower()
	local ent = self.ent
	if not IsValid(ent) then return end
	ent:SetNPCState(NPC_STATE_ALERT)
	self:RunSchedule(SCHED_COWER)
end

function NPCBody:SetDisposition(ent, disposition)
	if IsValid(self.ent) and IsValid(ent) then self.ent:AddEntityRelationship(ent, disposition, 99) end
end

function NPCBody:GetDisposition(ent)
	if not IsValid(self.ent) or not IsValid(ent) then return D_NU end
	return self.ent:Disposition(ent)
end

function NPCBody:SetEnemy(ent)
	local npc = self.ent
	if not IsValid(npc) then return end
	if not IsValid(ent) then
		npc:SetEnemy(NULL)
		return
	end
	npc:SetEnemy(ent)
	npc:SetTarget(ent)
	npc:UpdateEnemyMemory(ent, ent:GetPos())
end

function NPCBody:GetEnemy()
	return IsValid(self.ent) and self.ent:GetEnemy() or NULL
end

function NPCBody:GetEnemyLastTimeSeen(ent)
	if not IsValid(self.ent) or not IsValid(ent) then return 0 end
	return self.ent:GetEnemyLastTimeSeen(ent)
end

function NPCBody:SetAlertLevel(level)
	if IsValid(self.ent) then self.ent:SetNPCState(ALERT_STATES[level] or NPC_STATE_IDLE) end
end

function NPCBody:GiveWeapon(weapon_class)
	local ent = self.ent
	if not IsValid(ent) then return NULL end
	local weapon = ent:GetWeapon(weapon_class)
	if not IsValid(weapon) then weapon = ent:Give(weapon_class) end
	if IsValid(weapon) then ent:SelectWeapon(weapon_class) end
	return weapon
end

function NPCBody:GetActiveWeapon()
	if not IsValid(self.ent) then return NULL end
	local weapon = self.ent:GetActiveWeapon()
	return IsValid(weapon) and weapon or NULL
end

function NPCBody:PlaySequence(sequence_id)
	local ent = self.ent
	if not IsValid(ent) then return false end
	ent:SetNPCState(NPC_STATE_SCRIPT)
	self:RunSchedule(SCHED_NPC_FREEZE) -- the AI stays off while it plays (systems/sv_static_animation_controller.lua)
	ent:ResetSequenceInfo()
	ent:ResetSequence(sequence_id)
	ent:PhysWake()
	return true
end

function NPCBody:StopSequence()
	self:ClearSchedule()
end

function NPCBody:DropToFloor()
	local ent = self.ent
	if not IsValid(ent) then return end
	local hull = ent:GetHullType()
	ent:SetSolid(SOLID_BBOX)
	ent:SetPos(ent:GetPos() + ent:GetUp() * 6)
	ent:SetHullType(hull)
	ent:SetHullSizeNormal()
	ent:DropToFloor()
end
