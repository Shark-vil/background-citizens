--[[
	Sends actor state to the players that have the actor in their PVS.
	The static part (identity, model, name) goes only when it changes for that player (entering the PVS, rebind);
	the dynamic part goes when its CRC changes. Sends are capped per tick so PVS bursts spread over several ticks.
--]]
local Serialize = bgNPC.Net.Serialize
local SYNC_PERIOD = 0.25
local MAX_SENDS_PER_TICK = 8
local seq = 0 -- lets the client drop a dynamic part older than one it already applied
local function BuildStatic(actor)
  return {
    npc = actor:GetNPC(),
    actor_type = actor:GetType(),
    entity_generation = actor.entity_generation or 0,
    class = actor.class,
    model = actor.model,
    name = actor:GetName(),
    gender = actor:GetGender(),
  }
end

local function BuildDynamic(actor)
  return {
    state = actor:GetState(),
    state_group = bgNPC.States.GetGroup(actor:GetState()),
    enemies = actor.enemies,
    targets = actor.targets,
    anim_name = actor.anim_name,
    is_animated = actor.is_animated,
    state_lock = actor.state_lock,
    carry_visual = actor.carry_visual or false,
    reaction = actor.reaction,
  }
end

bgNPC.Tasks.Add('BGN_SynchronizationService', function(yield, wait, budget)
  local sends = 0
  while true do
    local players = player.GetHumans()
    local actors = bgNPC.Actors.GetAll()
    for i = 1, #actors do
      local actor = actors[i]
      local npc = actor and actor:IsAlive() and actor:GetNPC()
      if IsValid(npc) then
        local static, static_hash, dynamic, dynamic_hash
        local hashes = actor.sync_players_hash
        for k = 1, #players do
          local ply = players[k]
          if IsValid(ply) and ply.bgn_ready and (actor:InVehicle() or actor:HasState('knocked_down') or not npc:GetNoDraw()) and ply:TestPVS(npc) then
            if not dynamic_hash then
              static = BuildStatic(actor)
              static_hash = util.CRC(Serialize(static))
              dynamic = BuildDynamic(actor)
              dynamic_hash = util.CRC(Serialize(dynamic))
            end

            local sent = hashes[ply]
            local send_static = not sent or sent.static ~= static_hash
            if send_static or sent.dynamic ~= dynamic_hash then
              if sends >= MAX_SENDS_PER_TICK then
                yield()
                sends = 0
              end

              seq = seq + 1
              bgNPC.Net.Send('bgn_actor_sync_data', ply, actor.uid, dynamic, send_static and static or nil, seq)
              hashes[ply] = {
                static = static_hash,
                dynamic = dynamic_hash
              }

              sends = sends + 1
            end
          else
            hashes[ply] = nil
          end
        end
      end

      budget()
    end

    wait(SYNC_PERIOD)
    sends = 0
  end
end)
