local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
local H = Actor.Helpers
--

-- ---------------------------------------------------------------------------
-- Targets
-- ---------------------------------------------------------------------------
-- ? A target doesn't have to be an enemy. Targets are used by state logic.

function Actor:AddTarget(ent)
	Assert.Arg(1, ent, 'entity|nil', 'ACTOR:AddTarget')

	if not self.mechanics.targets_controller then return end
	if not IsValid(ent) or ent == self.npc or bgNPC.Combat.IsIgnored(ent) then return end
	if not self:IsAlive() or bgNPC.Table.HasValue(self.targets, ent) then return end

	self.targets_count = self.targets_count + 1
	self.targets[self.targets_count] = ent
end

-- Removes an entity from the target list.
-- ! Removing a target does not change NPC relationships.
-- @param ent entity|nil target to remove
-- @param index number|nil target index, takes priority over ent
-- @return number targets count after removal
function Actor:RemoveTarget(ent, index)
	Assert.Arg(2, index, 'number|nil', 'ACTOR:RemoveTarget')

	if not self.mechanics.targets_controller then return self.targets_count end

	if index then ent = self.targets[index] end
	if ent == nil then return self.targets_count end

	if hook.Run('BGN_RemoveActorTarget', self, ent) then return self.targets_count end

	local old_count = self.targets_count

	if ent == self.walkTarget then self.walkTarget = NULL end

	if index and self.targets[index] == ent then
		table.remove(self.targets, index)
	else
		table.RemoveByValue(self.targets, ent)
	end

	self.targets_count = #self.targets

	if old_count > 0 and self.targets_count == 0 then
		hook.Run('BGN_ResetTargetsForActor', self)
	end

	return self.targets_count
end

function Actor:RemoveAllTargets()
	if not self.mechanics.targets_controller then return end

	for i = self.targets_count, 1, -1 do
		self:RemoveTarget(nil, i)
	end

	-- Hooks may reject a removal; make sure the list is consistent anyway.
	if self.targets_count ~= 0 then
		self.targets = {}
		self.targets_count = 0
		hook.Run('BGN_ResetTargetsForActor', self)
	end
end

-- Removes dead or no longer existing targets.
-- @return table targets
function Actor:RecalculationTargets()
	if not self.mechanics.targets_controller then return self.targets end

	self.targets_count = #self.targets

	for i = self.targets_count, 1, -1 do
		local target = self.targets[i]
		if not IsValid(target) or (target:IsPlayer() and target:Health() <= 0) then
			self:RemoveTarget(nil, i)
		end
	end

	return self.targets
end

function Actor:HasTarget(ent)
	return bgNPC.Table.HasValue(self.targets, ent)
end

function Actor:TargetsCount()
	return self.targets_count
end

function Actor:HasNoTargets()
	return self.targets_count == 0
end

-- @return entity|NULL nearest target
function Actor:GetNearTarget()
	if not IsValid(self.npc) then return NULL end
	return H.FindNearest(self.targets, self.targets_count, self.npc:GetPos())
end

function Actor:GetTarget(index)
	Assert.Arg(1, index, 'number|nil', 'ACTOR:GetTarget')
	if index == nil then return self:GetFirstTarget() end
	return self.targets[index] or NULL
end

function Actor:GetFirstTarget()
	return H.FindFirstValid(self.targets, 1, self.targets_count, 1)
end

function Actor:GetLastTarget()
	return H.FindFirstValid(self.targets, self.targets_count, 1, -1)
end
