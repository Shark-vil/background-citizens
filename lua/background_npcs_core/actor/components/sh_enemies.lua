local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
local H = Actor.Helpers
--
-- ---------------------------------------------------------------------------
-- Enemies
-- ---------------------------------------------------------------------------
-- @param ent entity enemy (NPC, NextBot or player)
-- @param reaction string|nil 'fear' makes the NPC afraid instead of hostile
-- @param always_visible boolean|nil the enemy is never forgotten when out of sight
function Actor:AddEnemy(ent, reaction, always_visible)
  Assert.Arg(1, ent, 'entity|actor|nil', 'ACTOR:AddEnemy')
  Assert.Arg(2, reaction, 'string|nil', 'ACTOR:AddEnemy')
  Assert.Arg(3, always_visible, 'boolean|nil', 'ACTOR:AddEnemy')
  if not self.mechanics.enemies_controller then return end
  if bgNPC.Modes.IsPeaceful() then return end
  if istable(ent) then ent = ent:GetNPC() end
  if not IsValid(ent) or bgNPC.Combat.IsIgnored(ent) then return end
  -- also an actor seated in a car: its body is a Decent Vehicle entity
  if not bgNPC.Combat.IsAttacker(ent) then return end
  if not self:IsAlive() then return end
  local npc = self.npc
  if npc == ent or bgNPC.Table.HasValue(self.enemies, ent) then return end
  if self:HasTeam(ent) then return end
  if hook.Run('BGN_AddActorEnemy', self, ent) then return end
  local relationship = reaction == 'fear' and D_FR or D_HT
  self.enemies_count = self.enemies_count + 1
  self.enemies[self.enemies_count] = ent
  self.enemy_last_seen = self.enemy_last_seen or {}
  self.enemy_last_seen[ent] = CurTime() -- newly reported enemies get the normal search grace period
  -- a wanted target is known to the city even out of sight, otherwise a fresh reinforcement would stand still
  if bgNPC.Vision.HasLineOfSight(npc, ent, 'memory') or bgNPC.Modules.Get('wanted'):HasWanted(ent) then
    self.enemy_last_position = self.enemy_last_position or {}
    self.enemy_last_position[ent] = ent:GetPos()
  end
  if always_visible then
    self.enemies_always_visible_count = self.enemies_always_visible_count + 1
    self.enemies_always_visible[self.enemies_always_visible_count] = ent
  end

  local body = self.body
  if body then
    body:SetDisposition(ent, relationship)
    body:SetAlertLevel(relationship == D_HT and 'combat' or 'alert')
    -- the body would otherwise get its enemy on the next EnemiesRecalculate, up to a second later
    if not IsValid(body:GetEnemy()) then body:SetEnemy(ent, self.enemy_last_position and self.enemy_last_position[ent]) end
  end

  if SERVER and bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(self, 'enemy_added', ent) end
end

-- @param ent entity|nil enemy to remove
-- @param index number|nil enemy index, takes priority over ent
-- @return number enemies count after removal
function Actor:RemoveEnemy(ent, index)
  Assert.Arg(2, index, 'number|nil', 'ACTOR:RemoveEnemy')
  if not self.mechanics.enemies_controller then return self.enemies_count end
  if index then ent = self.enemies[index] end
  if ent == nil then return self.enemies_count end
  if hook.Run('BGN_RemoveActorEnemy', self, ent) then return self.enemies_count end
  local old_count = self.enemies_count
  local body = self.body
  if ent == self.walkTarget then self.walkTarget = NULL end
  if ent == self.combat_enemy then self.combat_enemy = nil end
  if body and IsValid(ent) then
    if body:GetEnemy() == ent then body:SetEnemy(NULL) end
    body:SetDisposition(ent, D_NU)
  end

  if index and self.enemies[index] == ent then
    table.remove(self.enemies, index)
  else
    table.RemoveByValue(self.enemies, ent)
  end

  table.RemoveByValue(self.enemies_always_visible, ent)
  if self.enemy_last_seen then self.enemy_last_seen[ent] = nil end
  if self.enemy_last_position then self.enemy_last_position[ent] = nil end
  self.enemies_count = #self.enemies
  self.enemies_always_visible_count = #self.enemies_always_visible
  if old_count > 0 and self.enemies_count == 0 then hook.Run('BGN_ResetEnemiesForActor', self) end
  return self.enemies_count
end

function Actor:RemoveAllEnemies()
  if not self.mechanics.enemies_controller then return end
  for i = self.enemies_count, 1, -1 do
    self:RemoveEnemy(nil, i)
  end

  -- Hooks may reject a removal; make sure the list is consistent anyway.
  if self.enemies_count ~= 0 then
    self.enemies = {}
    self.enemies_count = 0
    self.enemies_always_visible = {}
    self.enemies_always_visible_count = 0
    hook.Run('BGN_ResetEnemiesForActor', self)
  end
end

-- @param ent entity|actor
function Actor:HasEnemy(ent)
  if istable(ent) and ent.isBgnClass then ent = ent.npc end
  if not IsValid(ent) then return false end
  return bgNPC.Table.HasValue(self.enemies, ent)
end

function Actor:EnemiesCount()
  return self.enemies_count
end

function Actor:HasNoEnemies()
  return self.enemies_count == 0
end

-- Points the body at the driven vehicle when the enemy player is inside one.
-- @return boolean true if the enemy was redirected to a vehicle
local function RedirectEnemyToVehicle(body, enemy)
  local active_enemy = body:GetEnemy()
  if IsValid(enemy) and IsValid(active_enemy) and active_enemy:IsVehicle() and (not enemy:IsPlayer() or enemy:GetVehicle() ~= active_enemy) then body:SetDisposition(active_enemy, D_NU) end
  if not IsValid(enemy) or not enemy:IsPlayer() or not enemy:InVehicle() then return false end
  local vehicle = enemy:GetVehicle()
  local vehicle_parent = vehicle:GetParent()
  local new_enemy = IsValid(vehicle_parent) and vehicle_parent or vehicle
  body:SetEnemy(new_enemy)
  body:SetDisposition(new_enemy, D_HT)
  return true
end

local ENEMY_FORGET_TIME = 60
local CALM_ENEMY_FORGET_TIME = 20
local FEAR_STATES = {'fear', 'run_from_danger', 'dyspnea_danger'}
-- Removes dead enemies, forgets enemies that were not seen for a long time
-- and points the body at the selected combat target.
function Actor:EnemiesRecalculate()
  if not self.mechanics.enemies_controller then return end
  local body = self.body
  if not body or not body:IsValid() then return end
  self.enemies_count = #self.enemies
  self.enemies_always_visible_count = #self.enemies_always_visible
  for i = self.enemies_count, 1, -1 do
    local enemy = self.enemies[i]
    if not IsValid(enemy) or enemy:Health() <= 0 then
      if IsValid(enemy) and self:HasTeam('police') then self:Voice('police_target_down') end
      self:RemoveEnemy(nil, i)
    elseif enemy.bgn_always_visible or bgNPC.Vision.HasLineOfSight(self.npc, enemy, 'memory') then
      self.enemy_last_seen = self.enemy_last_seen or {}
      self.enemy_last_seen[enemy] = CurTime()
      self.enemy_last_position = self.enemy_last_position or {}
      self.enemy_last_position[enemy] = enemy:GetPos()
      -- A frightened actor stops fearing an actor that has not fought for a while, even in plain sight.
      if not enemy:IsPlayer() and self:HasState(FEAR_STATES) and not bgNPC.Combat.IsFighting(enemy) and not bgNPC.Modules.Get('wanted'):HasWanted(enemy) then
        self.enemy_calm_since = self.enemy_calm_since or {}
        self.enemy_calm_since[enemy] = self.enemy_calm_since[enemy] or CurTime()
        if self.enemy_calm_since[enemy] + CALM_ENEMY_FORGET_TIME < CurTime() then
          self.enemy_calm_since[enemy] = nil
          self:RemoveEnemy(enemy)
        end
      elseif self.enemy_calm_since then
        self.enemy_calm_since[enemy] = nil
      end
    else
      -- NPC pursuit writes refresh engine memory too; only sightings/reports may extend our search.
      local last_seen = self.enemy_last_seen and self.enemy_last_seen[enemy] or 0
      if not bgNPC.Modules.Get('wanted'):HasWanted(enemy) and not bgNPC.Table.HasValue(self.enemies_always_visible, enemy)
        and last_seen + ENEMY_FORGET_TIME < CurTime() then
        if self:HasTeam('police') then self:Voice('police_target_lost') end
        self:RemoveEnemy(enemy)
      end
    end
  end
  local enemy = self:GetEnemy()
  if not RedirectEnemyToVehicle(body, enemy) then
    body:SetEnemy(enemy, self.enemy_last_position and self.enemy_last_position[enemy])
  end
end

function Actor:GetEnemy()
  local function Valid(enemy) return IsValid(enemy) and enemy:Health() > 0 and self:HasEnemy(enemy) end
  local enemy = self.last_attacker
  if not Valid(enemy) or CurTime() - (self.last_attacked_at or 0) > 5 then
    enemy = self.siege and self.siege.enemy
    if not Valid(enemy) then enemy = self.squad and self.squad.enemy end
    if not Valid(enemy) then enemy = self.combat_enemy end
    if not Valid(enemy) then
      enemy = NULL
      local distance
      for _, candidate in ipairs(self.enemies) do
        if Valid(candidate) then
          local d = self:GetPos():DistToSqr(candidate:GetPos())
          if not distance or d < distance then enemy, distance = candidate, d end
        end
      end
    end
  end
  self.combat_enemy = IsValid(enemy) and enemy or nil
  return enemy
end

function Actor:ShareEnemyMemory(source, enemy)
  if not self:HasEnemy(enemy) then return false end
  local pos = source.enemy_last_position and source.enemy_last_position[enemy]
  local seen = source.enemy_last_seen and source.enemy_last_seen[enemy]
  if not pos or not seen or CurTime() - seen > ENEMY_FORGET_TIME then return false end
  if self.enemy_last_position and self.enemy_last_position[enemy] and self.enemy_last_seen
    and (self.enemy_last_seen[enemy] or 0) >= seen then return false end
  self.enemy_last_position = self.enemy_last_position or {}
  self.enemy_last_seen = self.enemy_last_seen or {}
  self.enemy_last_position[enemy], self.enemy_last_seen[enemy] = Vector(pos), seen
  return true
end

function Actor:GetFirstEnemy()
  return H.FindFirstValid(self.enemies, 1, self.enemies_count, 1)
end

function Actor:GetLastEnemy()
  return H.FindFirstValid(self.enemies, self.enemies_count, 1, -1)
end

function Actor:GetNearEnemy()
  if not IsValid(self.npc) then return NULL end
  return H.FindNearest(self.enemies, self.enemies_count, self.npc:GetPos())
end
