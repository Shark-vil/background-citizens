--
-- Listeners react only up to 80 units (doors) and 50 units (police luggage push); a wider sphere just fed them
-- objects they discard, and every one cost a visibility trace.
local SCAN_RADIUS = 100
local function ParseEntitiesForActorAsync(actor)
  local npc = actor:GetNPC()
  local npc_pos = npc:GetPos()
  local entities = ents.FindInSphere(npc_pos, SCAN_RADIUS)
  local look_hit -- the forward trace does not depend on the object: traced once per scan, on first need
  for k = 1, #entities do
    bgNPC.Tasks.Budget()
    local ent = entities[k]
    if not IsValid(ent) then continue end
    local ent_pos = ent:GetPos()
    if not actor:IsAlive() or actor:GetNPC() ~= npc then break end
    if not bgNPC.Vision.NPCCanSeePos(npc, ent_pos, 85) then continue end
    local diff = (ent_pos - npc_pos):Angle().y - npc:GetAngles().y
    if diff < -180 then diff = diff + 360 end
    if diff > 180 then diff = diff - 360 end
    diff = math.abs(diff)
    local dist = npc_pos:Distance(ent_pos)
    hook.Run('BGN_ActorVisibleAtObject', actor, ent, dist, diff)
    if not IsValid(npc) or actor:GetNPC() ~= npc then break end
    if npc:IsNPC() then
      if look_hit == nil then
        local start = npc:GetShootPos()
        look_hit = util.TraceLine({
          start = start,
          endpos = start + npc:GetForward() * 1000,
          filter = npc
        }).Hit
      end

      if look_hit and IsValid(ent) and actor:IsAlive() then hook.Run('BGN_ActorLookAtObject', actor, ent, dist, diff) end
    end
  end
end

bgNPC.Tasks.Add('BGN_Timer_ActorLookAtObject', function()
  while true do
    local actors = bgNPC.Actors.GetAll()
    for i = 1, #actors do
      local actor = actors[i]
      if actor and actor:IsAlive() then ParseEntitiesForActorAsync(actor) end
      coroutine.yield()
    end

    coroutine.yield()
  end
end)
