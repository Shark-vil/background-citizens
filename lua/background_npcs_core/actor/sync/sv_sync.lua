--[[
	Sends actor state to the players that have the actor in their PVS.
	Each player gets the data only when it changed (CRC of the serialized data).
--]]
local Serialize = bgNPC.Net.Serialize
local SYNC_PERIOD = 0.25
local function BuildSyncData(actor)
  return {
    npc = actor:GetNPC(),
    actor_type = actor:GetType(),
    entity_generation = actor.entity_generation or 0,
    class = actor.class,
    model = actor.model,
    name = actor:GetName(),
    gender = actor:GetGender(),
    state = actor:GetState(),
    state_group = bgNPC.States.GetGroup(actor:GetState()),
    enemies = actor.enemies,
    targets = actor.targets,
    anim_name = actor.anim_name,
    is_animated = actor.is_animated,
    state_lock = actor.state_lock,
    carry_visual = actor.carry_visual or false,
    reaction = actor.reaction,
    npc_schedule = actor.npc_schedule,
    npc_state = actor.npc_state,
  }
end

bgNPC.Tasks.Add('BGN_SynchronizationService', function(yield, wait, budget)
  while true do
    local players = player.GetHumans()
    local actors = bgNPC.Actors.GetAll()
    for i = 1, #actors do
      local actor = actors[i]
      local npc = actor and actor:IsAlive() and actor:GetNPC()
      if IsValid(npc) then
        local sync_data, sync_hash
        for k = 1, #players do
          local ply = players[k]
          if IsValid(ply) and ply.bgn_ready and (actor:InVehicle() or actor:HasState('knocked_down') or not npc:GetNoDraw()) and ply:TestPVS(npc) then
            if not sync_hash then
              sync_data = BuildSyncData(actor)
              sync_hash = util.CRC(Serialize(sync_data))
            end

            if actor.sync_players_hash[ply] ~= sync_hash then
              bgNPC.Net.Send('bgn_actor_sync_data', ply, actor.uid, sync_data)
              actor.sync_players_hash[ply] = sync_hash
            end
          else
            actor.sync_players_hash[ply] = nil
          end
        end
      end

      budget()
    end

    wait(SYNC_PERIOD)
  end
end)
