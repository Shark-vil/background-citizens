--[[
	Corpse cleanup: the body of a dead actor (NPC or NextBot) fades out bgn_corpse_cleanup_time seconds after
	the death (bgn_corpse_cleanup). A body a medic is coming for or an officer is inspecting waits for them:
	the medic call and the inspection end on their own (systems/sv_medics.lua, states/sv_police_inspect_body.lua).
	Server ragdolls fade here, client ragdolls on every client (systems/cl_corpses.lua).
	with the cleanup on, npc_battle_cleanup leaves the actors' bodies alone (doNotRemove here, client side in cl_corpses.lua).
--]]
local cvar_enabled = GetConVar('bgn_corpse_cleanup')
local cvar_time = GetConVar('bgn_corpse_cleanup_time')
local BUSY_DIST_SQR = 200 ^ 2
local FADE_STEP = 5 -- alpha per tick: ~0.8 s
local bodies = {}
local function Find(npc)
  for i = #bodies, 1, -1 do
    if bodies[i].npc == npc then return bodies[i] end
  end
end

local function Add(npc)
  local body = {
    npc = npc,
    pos = npc:GetPos(),
    time = CurTime()
  }

  bodies[#bodies + 1] = body
  return body
end

hook.Add('BGN_OnKilledActor', 'BGN_Corpses', function(actor)
  local npc = actor:GetNPC()
  if actor:InVehicle() or not IsValid(npc) or Find(npc) then return end
  Add(npc)
end)

-- fires after OnNPCKilled (BGN_OnKilledActor) for NPCs and NextBots
hook.Add('CreateEntityRagdoll', 'BGN_Corpses', function(owner, ragdoll)
  local body = Find(owner)
  if not body then return end
  if cvar_enabled:GetBool() then -- npc_battle_cleanup: only while our cleanup runs
    ragdoll.doNotRemove = true
  end

  body.ragdoll = ragdoll
end)

-- a medic call and a body come from the same death: same position (the entities may be gone by now)
local function SameDeath(call, body)
  return call.pos:DistToSqr(body.pos) < 1
end

hook.Add('BGN_ActorRevived', 'BGN_Corpses', function(_, call)
  for _, body in ipairs(bodies) do
    if SameDeath(call, body) then body.done = true end
  end
end)

local function IsBusy(body)
  for _, call in ipairs(bgNPC.Medics and bgNPC.Medics.calls or {}) do
    if call.medic and SameDeath(call, body) then return true end
  end

  for _, officer in ipairs(bgNPC.Actors.GetByTeam('police')) do
    local data = officer:HasState('police_inspect_body') and officer:GetStateData()
    if data and data.body and data.body.pos:DistToSqr(body.pos) < BUSY_DIST_SQR then return true end
  end
  return false
end

local function Remove(body)
  for _, call in ipairs(bgNPC.Medics and bgNPC.Medics.calls or {}) do
    if SameDeath(call, body) then call.gone = true end
  end

  if body.ragdoll then
    bgNPC.Util.FadeRemove(body.ragdoll, FADE_STEP)
  else
    bgNPC.Net.Send('bgn.body_remove', nil, body.pos, true)
  end
end

timer.Create('BGN_Corpses', 2, 0, function()
  if not cvar_enabled:GetBool() then -- off: the bodies stay
    return table.Empty(bodies)
  end

  local deadline = CurTime() - cvar_time:GetFloat()
  for i = #bodies, 1, -1 do
    local body = bodies[i]
    if body.done or (body.ragdoll and not IsValid(body.ragdoll)) then
      table.remove(bodies, i)
    elseif body.time <= deadline and not IsBusy(body) then
      table.remove(bodies, i)
      Remove(body)
    end
  end
end)
