-- Rival gangs may start a fight; visible allies join through sv_enemy_sharing.lua.
local WAR_PERIOD = 10
local WAR_RADIUS = 700
local cvar_war = GetConVar('bgn_gang_war_chance')
local function GangOf(actor)
  return actor.data and actor.data.gang
end

-- Two gangs near each other sometimes go for each other's throats.
timer.Create('BGN_GangWar', WAR_PERIOD, 0, function()
  local chance = cvar_war:GetFloat()
  if chance <= 0 or bgNPC.Modes.IsPeaceful() then return end
  for _, actor in ipairs(bgNPC.Actors.GetAll()) do
    local gang = GangOf(actor)
    if gang and actor:IsAlive() and not actor:InVehicle() and actor:HasNoEnemies() and actor:EqualStateGroup('calm') and math.random() * 100 < chance then
      local npc = actor:GetNPC()
      for _, other in ipairs(bgNPC.Actors.GetInRadius(npc:GetPos(), WAR_RADIUS)) do
        local other_gang = GangOf(other)
        if other_gang and other_gang ~= gang and other:IsAlive() and not other:InVehicle() and other:EqualStateGroup('calm') and bgNPC.Vision.HasLineOfSight(npc, other:GetNPC()) then
          actor:AddEnemy(other:GetNPC())
          other:AddEnemy(npc)
          actor:SetState('defense')
          other:SetState('defense')
          break
        end
      end
    end
  end
end)
