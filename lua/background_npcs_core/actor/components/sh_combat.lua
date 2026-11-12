local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
local H = Actor.Helpers
--
local MALE_SCREAMS = {'ambient/voices/m_scream1.wav', 'vo/coast/bugbait/sandy_help.wav', 'vo/npc/male01/help01.wav', 'vo/Streetwar/sniper/male01/c17_09_help01.wav', 'vo/Streetwar/sniper/male01/c17_09_help02.wav', 'vo/npc/male01/no01.wav', 'vo/npc/male01/no02.wav',}
local FEMALE_SCREAMS = {'ambient/voices/f_scream1.wav', 'vo/canals/arrest_helpme.wav', 'vo/npc/female01/help01.wav', 'vo/npc/female01/no01.wav', 'vo/npc/female01/no02.wav',}
local ANY_SCREAMS = {}
for _, path in ipairs(MALE_SCREAMS) do
  ANY_SCREAMS[#ANY_SCREAMS + 1] = path
end

for _, path in ipairs(FEMALE_SCREAMS) do
  ANY_SCREAMS[#ANY_SCREAMS + 1] = path
end

-- ---------------------------------------------------------------------------
-- Fear and help
-- ---------------------------------------------------------------------------
function Actor:FearScream()
  if not self.mechanics.fear_scream then return end
  if not self:IsAlive() then return end
  local gender = H.GenderByModel(self.npc:GetModel())
  local screams = gender == 'female' and FEMALE_SCREAMS or gender == 'male' and MALE_SCREAMS or ANY_SCREAMS
  self.npc:EmitSound(bgNPC.Table.Random(screams), 100, 100, 1, CHAN_AUTO)
end

function Actor:Fear()
  if not self.mechanics.fear then return end
  if not self.body or not self:IsAlive() then return end
  self.body:Cower()
end

-- Screams and asks nearby teammates who can see the enemy to protect the actor.
function Actor:CallForHelp(enemy)
  Assert.Arg(1, enemy, 'entity|nil', 'ACTOR:CallForHelp')
  if not self.mechanics.call_for_help then return end
  if not IsValid(enemy) or not self:IsAlive() then return end
  if hook.Run('BGN_PreCallForHelp', self, enemy) then return end
  -- panic spreads only from a real fight; an officer's call needs no fight
  if not self:HasTeam('police') and not bgNPC.Combat.IsFighting(enemy) then return end
  self:FearScream()
  local near_actors = bgNPC.Actors.GetInRadius(self.npc:GetPos(), 1000)
  for i = 1, #near_actors do
    local near_actor = near_actors[i]
    if near_actor ~= self and near_actor:IsAlive() and near_actor:HasTeam(self) and bgNPC.Vision.HasLineOfSight(near_actor.npc, enemy, 'help') then
      near_actor:SetState(near_actor:GetReactionForProtect(enemy))
      if near_actor.protect_blocked_enemy ~= enemy then
        near_actor:AddEnemy(enemy)
        if SERVER and bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(near_actor, 'help', enemy, nil, self.npc, near_actor:HasEnemy(enemy)) end
      elseif SERVER and bgNPC.DebugInspector then
        bgNPC.DebugInspector.Emit(near_actor, 'help', enemy, 'reaction_blocked', self.npc, false)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Weapons
-- ---------------------------------------------------------------------------
function Actor:CreateFakePlayerMethodsForNPC()
  local npc = self.npc
  if not IsValid(npc) then return end
  -- Fixes some weapon mods that expect player methods on the owner.
  if not isfunction(npc.LagCompensation) then
    function npc:LagCompensation()
    end
  end

  if not isfunction(npc.GetViewModel) then
    function npc:GetViewModel()
    end
  end
end

function Actor:IsMeleeWeapon()
  if not self:IsAlive() then return false end
  local weapon = self:GetActiveWeapon()
  local weapon_class = IsValid(weapon) and weapon:GetClass() or self.weapon
  -- No weapon in hand and no intended weapon: treat as ranged, so the
  -- defense state holds distance instead of rushing the enemy.
  if not weapon_class then return false end
  return bgNPC.Table.HasValue(bgNPC.cfg.melee_weapons, weapon_class)
end

-- Returns the weapon class assigned to the actor on creation.
function Actor:GetActorWeapon()
  return self.weapon
end

function Actor:GetActiveWeapon()
  if not self.body or not self:IsAlive() then
    local weapon = IsValid(self.npc) and self.npc.GetActiveWeapon and self.npc:GetActiveWeapon()
    if IsValid(weapon) and (weapon:GetClass() == 'weapon_citizenpackage' or weapon:GetClass() == 'weapon_citizensuitcase') then return NULL end
    return IsValid(weapon) and weapon or NULL
  end
  return self.body:GetActiveWeapon()
end

function Actor:HasActiveWeapon()
  return IsValid(self:GetActiveWeapon())
end

-- Gives and selects a weapon. Without a class, the actor's own weapon is used.
function Actor:PrepareWeapon(weapon_class, switching)
  Assert.Arg(1, weapon_class, 'string|nil', 'ACTOR:PrepareWeapon')
  Assert.Arg(2, switching, 'boolean|nil', 'ACTOR:PrepareWeapon')
  bgNPC.Combat.EquipActor(self, weapon_class, switching)
end

function Actor:FoldWeapon()
  if self.disable_fold_weapon then return end
  local weapon = self:GetActiveWeapon()
  if IsValid(weapon) then weapon:Remove() end
end

function Actor:GiveWeapon(weapon_class)
  Assert.Arg(1, weapon_class, 'string|nil', 'ACTOR:GiveWeapon')
  self.weapon = weapon_class
end
