--[[
	Body: what an actor needs from the entity it controls, independent of the engine AI.
	Implementations: NPCBody (HL2 NPC, engine schedules), NextBotBody (bgn_nextbot).

	Brains, states and actor components talk to the body, never to the entity's AI directly,
	so the same logic drives an NPC and a NextBot.
--]]

local Body = bgNPC.Class('BGN_Body')
bgNPC.Body = Body

-- Dispositions, same values as the engine D_* enums.
Body.HATE = D_HT
Body.FEAR = D_FR
Body.NEUTRAL = D_NU
Body.LIKE = D_LI

function Body:Init(actor, ent)
	self.actor = actor
	self.ent = ent
end

function Body:GetEntity() return self.ent end
function Body:IsValid() return IsValid(self.ent) end
function Body:IsNPC() return false end
function Body:IsNextBot() return false end

function Body:IsDead()
	local ent = self.ent
	return not IsValid(ent) or ent:Health() <= 0
end

-- Movement -------------------------------------------------------------

-- Walks (or runs) to a point in a straight line, the actor's path is fed node by node.
function Body:MoveTo(pos, run) end
function Body:StopMoving() end
function Body:IsMoving() return false end
-- Steps away from the current enemy (short retreat).
function Body:MoveAwayFromEnemy() end
-- Stands still and keeps the AI from walking away (dialogues, scripted moments).
function Body:HoldStill() self:StopMoving() end
-- Plays the cower / scared reaction.
function Body:Cower() end
-- Runs an engine schedule id. NPCs execute it as is, other bodies map the common ones.
function Body:RunSchedule(schedule) end
function Body:ClearSchedule() end
-- True while the body runs its own combat logic (shooting, reloading) that must not be interrupted.
function Body:IsBusyInCombat() return false end

-- Combat ---------------------------------------------------------------

function Body:SetDisposition(ent, disposition) end
function Body:GetDisposition(ent) return D_NU end
function Body:SetEnemy(ent) end
function Body:GetEnemy() return NULL end
function Body:GetEnemyLastTimeSeen(ent) return CurTime() end
-- level: 'idle' | 'alert' | 'combat'
function Body:SetAlertLevel(level) end

function Body:GiveWeapon(weapon_class) end
function Body:GetActiveWeapon() return NULL end
function Body:RemoveActiveWeapon()
	local weapon = self:GetActiveWeapon()
	if IsValid(weapon) then weapon:Remove() end
end

-- Animation ------------------------------------------------------------

-- Holds the AI and plays a sequence. @return boolean started
function Body:PlaySequence(sequence_id) return false end
-- Returns control to the AI.
function Body:StopSequence() end

-- LOD ------------------------------------------------------------------

-- Disabled thinking freezes the engine AI of a far, unseen actor.
function Body:SetThinkEnabled(enabled)
	local ent = self.ent
	if not IsValid(ent) then return end
	if enabled then ent:RemoveEFlags(EFL_NO_THINK_FUNCTION) else ent:AddEFlags(EFL_NO_THINK_FUNCTION) end
end

function Body:IsThinkEnabled()
	return IsValid(self.ent) and not self.ent:IsEFlagSet(EFL_NO_THINK_FUNCTION)
end

function Body:DropToFloor()
	if IsValid(self.ent) then self.ent:DropToFloor() end
end

-- Picks the body class for an entity.
function Body.For(actor, ent)
	if ent:IsNPC() then return bgNPC.NPCBody(actor, ent) end
	if ent.IsBGNNextBot then return bgNPC.NextBotBody(actor, ent) end
	return Body(actor, ent)
end
