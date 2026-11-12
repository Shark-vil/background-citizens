-- Foreign NPCs use their most common disposition towards server players for NextBot bodies.
-- FL_OBJECT on bgn_nextbot lets HL2 NPC senses detect them without helper NPCs.
local PERIOD = 1
local RANGE_SQR = 2500 ^ 2
local cvar_ignore_another_npc = GetConVar('bgn_ignore_another_npc')
local function GetPlayersDisposition(npc, players)
  local counts = {}
  for _, ply in ipairs(players) do
    local disposition = npc:Disposition(ply)
    counts[disposition] = (counts[disposition] or 0) + 1
  end

  local result, highest = D_NU, 0
  for disposition, count in pairs(counts) do
    if count > highest then
      result, highest = disposition, count
    elseif count == highest then
      result = D_NU
    end
  end
  return result
end

bgNPC.NextBotBody.GetPlayersDisposition = GetPlayersDisposition
timer.Create('BGN_Timer_NextBotHostility', PERIOD, 0, function()
  if bgNPC.Modes.IsPeaceful() or cvar_ignore_another_npc:GetBool() then return end
  local bots = {}
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    local body = actor:IsAlive() and actor:GetNPC()
    if IsValid(body) and body:IsNextBot() and not actor:InVehicle() then bots[#bots + 1] = actor end
  end

  if #bots == 0 then return end
  local players = player.GetAll()
  for _, npc in ipairs(ents.GetAll()) do
    if IsValid(npc) and npc:IsNPC() and not npc.isBgnActor and npc:Health() > 0 then
      local pos = npc:GetPos()
      local disposition = GetPlayersDisposition(npc, players)
      for _, actor in ipairs(bots) do
        local body = actor:GetNPC()
        if pos:DistToSqr(body:GetPos()) <= RANGE_SQR and npc:Disposition(body) ~= disposition then npc:AddEntityRelationship(body, disposition, 100) end
      end
    end
  end
end)
