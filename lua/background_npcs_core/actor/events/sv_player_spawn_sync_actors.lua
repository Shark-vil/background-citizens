--
hook.Add('BGN_PlayerReady', 'BGN_PlayerFirstInitSpawnerHook', function(ply)
  local delay = 0
  local actors = bgNPC.Actors.GetAll()
  for i = 1, #actors do
    local actor = actors[i]
    if actor:IsAlive() then
      local npc_type = actor:GetType()
      local npc = actor:GetNPC()
      actor:GetBody():SetDisposition(ply, D_NU)
      timer.Simple(delay, function()
        if not IsValid(ply) or not actor:IsAlive() or not IsValid(actor:GetNPC()) then return end
        bgNPC.Net.Send('bgn_add_actor_from_client', ply, actor:GetNPC(), npc_type, actor.uid, actor.info, actor.entity_generation or 0, actor.class, actor.model)
      end)

      delay = delay + 0.1
    end
  end
end)
