-- Warm-up: on the first player spawn every configured NPC class/model and vehicle is created once and removed,
-- so the engine loads their resources now instead of as a hitch during gameplay.
local function Warm(job)
  local pos, ang = vector_origin, angle_zero
  if job.vehicle then
    local vehicle = bgNPC:SpawnVehicle(job.vehicle, pos, ang)
    if IsValid(vehicle) then vehicle:Remove() end
    return
  end

  local npc = ents.Create(job.class)
  if not IsValid(npc) then return end
  npc:SetPos(pos)
  npc:SetAngles(ang)
  npc:Spawn()
  for _, model in ipairs(job.models) do
    npc:SetModel(model)
  end

  npc:Activate()
  npc:Remove()
end

local function AsList(value)
  if istable(value) then return value end
  return value and {value} or {}
end

hook.Add('PlayerSpawn', 'BGN_PreSpawnEntities_CacheService', function()
  hook.Remove('PlayerSpawn', 'BGN_PreSpawnEntities_CacheService')
  for _, cfg in pairs(bgNPC.cfg.actors) do
    for _, class in ipairs(AsList(cfg.class)) do
      Warm({
        class = class,
        models = AsList(cfg.models)
      })
    end

    for _, vehicle in ipairs(AsList(cfg.vehicles)) do
      Warm({
        vehicle = vehicle
      })
    end
  end
end)
