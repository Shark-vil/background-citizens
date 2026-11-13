local Actor = bgNPC.Actor
local Assert = bgNPC.Assert
--
-- ---------------------------------------------------------------------------
-- Relationships and teams
-- ---------------------------------------------------------------------------
-- Returns the relationship from the actor's config for the given entity or actor.
function Actor:GetRelationship(value, default)
  local relationship = self.relationship
  local actor
  if istable(value) and value.isBgnClass then
    actor = value
  elseif IsValid(value) then
    actor = bgNPC.Actors.Get(value)
  end

  if actor then
    if self:HasTeam(actor) then return relationship['@team'] or default end
    return relationship['@actor'] or default
  end

  if not IsValid(value) or not isentity(value) then return default end
  local by_class = relationship[value:GetClass()]
  if by_class then return by_class end
  if value:IsNPC() or value:IsNextBot() then
    return relationship['@npc'] or default
  elseif value:IsPlayer() then
    return relationship['@player'] or default
  end
  return default
end

local function TeamsIntersect(team_a, team_b)
  for i = 1, #team_a do
    local name = team_a[i]
    for k = 1, #team_b do
      if name == team_b[k] then return true end
    end
  end
  return false
end

-- Checks whether the value belongs to one of the actor's teams.
-- @param value string|entity|actor|table team name, entity, actor or list of team names
function Actor:HasTeam(value)
  local own_team = self.data and self.data.team
  if not own_team or value == nil then return false end
  if isstring(value) then return bgNPC.Table.HasValue(own_team, value) end
  if isentity(value) then
    if not IsValid(value) then return false end
    if value:IsPlayer() then return bgNPC.Table.HasValue(own_team, 'player') or bgNPC.Modules.Get('team_parent'):HasParent(value, self) end
    value = bgNPC.Actors.Get(value)
    if not value then return false end
  end

  if not istable(value) then return false end
  if value.isBgnClass then
    local data = value:GetData()
    -- "bandits" is only for the police and the cars: loners, thieves and rival gangs are not teammates,
    -- members of one gang are (through their "gang_*" team)
    local gang = self.data.gang
    value = data and data.team
    if not istable(value) then return false end
    if bgNPC.Table.HasValue(own_team, 'bandits') and bgNPC.Table.HasValue(value, 'bandits') and (not gang or data.gang ~= gang) then return false end
  end

  if not bgNPC.Table.IsArray(value) then return false end
  return TeamsIntersect(own_team, value)
end

function Actor:SetTeam(team_data)
  Assert.Arg(1, team_data, 'table|nil', 'ACTOR:SetTeam')
  self.data.team = team_data
  if SERVER then
    for _, other in ipairs(bgNPC.Actors.GetAll()) do
      if other ~= self and other:HasTeam(self) then
        other:RemoveEnemy(self.npc)
        self:RemoveEnemy(other:GetNPC())
      end
    end

    local wanted = bgNPC.Modules.Get('wanted')
    if wanted and self:HasTeam('residents') then wanted:RemoveWanted(self.npc) end
    local arrest = bgNPC.Modules.Get('player_arrest')
    local component = arrest and arrest:GetTarget(self.npc)
    if component and component.policeActor and component.policeActor:HasTeam(self) then arrest:RemoveTarget(self.npc) end
  end
end

function Actor:AddTeam(team_name)
  Assert.NonEmptyString(1, team_name, 'ACTOR:AddTeam')
  self.data.team = self.data.team or {}
  if not bgNPC.Table.HasValue(self.data.team, team_name) then
    table.insert(self.data.team, team_name)
    self:SetTeam(self.data.team)
  end
end
