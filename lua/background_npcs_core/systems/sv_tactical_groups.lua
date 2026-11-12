--[[
	Squads (cvar "bgn_module_tactical_groups"): armed actors of one team that fight near each other act as a group.

	Every UPDATE_PERIOD the actors in the "defense" state are grouped: same team, within SQUAD_RADIUS of the leader,
	at most MAX_SIZE. The healthiest actor leads; its nearest enemy becomes the target of the whole squad
	(every member gets it as an enemy, so they engage together).

	Formation, facing the target:
		column - nobody in the squad sees the target: advance in file
		wedge  - 4+ healthy members and the target is seen
		line   - otherwise: abreast
	Members are ranked by health fraction: the healthiest stand in front, the wounded (< WOUNDED_FRACTION)
	form a rear rank behind the formation.

	Result: actor.squad = { squad, enemy, slot, role = 'front' | 'rear' }. The defense state moves the actor
	to its slot instead of its own repositioning; shooting stays with the body (engine NPC / NextBot).
--]]
local cvar_enabled = GetConVar('bgn_module_tactical_groups')
local UPDATE_PERIOD = 1
local SQUAD_RADIUS_SQR = 1200 ^ 2
local MAX_SIZE = 5
local WOUNDED_FRACTION = 0.4
local ENGAGE_DIST = 550
local SPACING = 90
local REAR_GAP = 250
local UP = Vector(0, 0, 1)
local Squads = {
  list = {}
}

bgNPC.Squads = Squads
local function HealthFraction(actor)
  local npc = actor:GetNPC()
  local max = npc:GetMaxHealth()
  return max > 0 and npc:Health() / max or 1
end

local function CanJoin(actor)
  return actor:IsAlive() and actor:GetState() == 'defense' and actor.weapon ~= nil and not actor:HasNoEnemies() and not actor:InVehicle() and not actor:IsMeleeWeapon()
end

local function SnapToNav(pos)
  if not navmesh.IsLoaded() then return pos end
  local area = navmesh.GetNearestNavArea(pos, false, 250)
  return area and area:GetClosestPointOnArea(pos) or pos
end

-- @return table { { forward, right } } offsets of n ranked members from the formation anchor
function Squads.FormationOffsets(formation, n)
  local offsets = {}
  for i = 1, n do
    local k = i - 1
    if formation == 'column' then
      offsets[i] = {-k * SPACING, 0}
    elseif formation == 'wedge' then
      local row = math.ceil(k / 2)
      local side = k == 0 and 0 or (k % 2 == 1 and 1 or -1)
      offsets[i] = {-row * SPACING, side * row * SPACING}
    else
      offsets[i] = {0, (k - (n - 1) / 2) * SPACING}
    end
  end
  return offsets
end

-- Groups the candidates greedily, healthiest first, so every squad is led by its healthiest member.
local function Build(candidates)
  table.sort(candidates, function(a, b) return HealthFraction(a) > HealthFraction(b) end)
  local squads, taken = {}, {}
  for _, leader in ipairs(candidates) do
    if not taken[leader] then
      taken[leader] = true
      local members = {leader}
      local pos = leader:GetPos()
      for _, other in ipairs(candidates) do
        if #members >= MAX_SIZE then break end
        if not taken[other] and other:HasTeam(leader) and other:GetPos():DistToSqr(pos) <= SQUAD_RADIUS_SQR then
          taken[other] = true
          members[#members + 1] = other
        end
      end

      if #members > 1 then
        squads[#squads + 1] = {
          leader = leader,
          members = members
        }
      end
    end
  end
  return squads
end

local function Assign(squad)
  local enemy = squad.leader:GetNearEnemy()
  if not IsValid(enemy) then return end
  local members = squad.members
  local center = Vector()
  local sees = false
  for _, member in ipairs(members) do
    center:Add(member:GetPos())
    sees = sees or bgNPC.Vision.HasLineOfSight(member:GetNPC(), enemy, 'squad')
  end

  center:Div(#members)
  local enemy_pos = enemy:GetPos()
  local forward = enemy_pos - center
  forward.z = 0
  if forward:LengthSqr() < 1 then forward = squad.leader:GetNPC():GetForward() end
  forward:Normalize()
  local right = forward:Cross(UP)
  -- members are sorted by health already; the leader is always in front
  local front, rear = {}, {}
  for _, member in ipairs(members) do
    if #front ~= 0 and HealthFraction(member) < WOUNDED_FRACTION then
      rear[#rear + 1] = member
    else
      front[#front + 1] = member
    end
  end

  local formation = not sees and 'column' or (#front >= 4 and 'wedge' or 'line')
  squad.formation, squad.enemy = formation, enemy
  -- police leaders call the new formation on the radio (at most every 8 s: "sees" can flicker)
  local leader = squad.leader
  if leader:HasTeam('police') and leader.vo_formation ~= formation and (leader.vo_formation_time or 0) < CurTime() then
    leader.vo_formation, leader.vo_formation_time = formation, CurTime() + 8
    leader:Voice('police_squad_' .. formation)
  end

  local anchor = enemy_pos - forward * ENGAGE_DIST
  local depth = 0
  local function Place(list, offsets, base, role)
    for i, member in ipairs(list) do
      local offset = offsets[i]
      depth = math.min(depth, offset[1])
      member.squad = {
        squad = squad,
        enemy = enemy,
        role = role,
        slot = SnapToNav(base + forward * offset[1] + right * offset[2]),
      }

      member:AddEnemy(enemy)
      if bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(member, 'squad', enemy, nil, squad.leader:GetNPC(), member:HasEnemy(enemy)) end
      if role == 'rear' and member.vo_role ~= 'rear' and member:HasTeam('police') then member:Voice('police_squad_rear') end
      member.vo_role = role
    end
  end

  Place(front, Squads.FormationOffsets(formation, #front), anchor, 'front')
  Place(rear, Squads.FormationOffsets('line', #rear), anchor + forward * (depth - REAR_GAP), 'rear')
end

local function Update()
  local candidates = {}
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    actor.squad = nil
    if CanJoin(actor) then candidates[#candidates + 1] = actor end
  end

  Squads.list = Build(candidates)
  for _, squad in ipairs(Squads.list) do
    Assign(squad)
  end
end

local function Start()
  timer.Create('BGN_TacticalGroupUpdate', UPDATE_PERIOD, 0, function()
    local ok, err = pcall(Update)
    if not ok then ErrorNoHalt('[Background NPCs] Squad update error: ' .. tostring(err) .. '\n') end
  end)
end

local function Stop()
  timer.Remove('BGN_TacticalGroupUpdate')
  Squads.list = {}
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    actor.squad = nil
  end
end

cvars.AddChangeCallback('bgn_module_tactical_groups', function(_, _, value)
  if tonumber(value) == 1 then
    Start()
  else
    Stop()
  end
end, 'tg_bgn_module_tactical_groups')

if cvar_enabled:GetBool() then Start() end
bgNPC.Test.Add('squads.formations', function(check)
  local line = Squads.FormationOffsets('line', 3)
  check(line[1][2] == -SPACING and line[2][2] == 0 and line[3][2] == SPACING, 'line is abreast and centered')
  local wedge = Squads.FormationOffsets('wedge', 5)
  check(wedge[1][1] == 0 and wedge[1][2] == 0, 'wedge tip is the leader')
  check(wedge[2][1] == wedge[3][1] and wedge[2][2] == -wedge[3][2], 'wedge rows are symmetric')
  check(wedge[4][1] < wedge[2][1], 'wedge widens backwards')
  local column = Squads.FormationOffsets('column', 3)
  check(column[3][1] == -2 * SPACING and column[3][2] == 0, 'column is in file')
end)
