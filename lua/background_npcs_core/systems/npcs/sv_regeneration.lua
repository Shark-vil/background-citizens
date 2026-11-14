bgNPC.Tasks.Add('BGN_ActorsRegeneration', function(yield, wait)
  while true do
    local actors = bgNPC.Actors.GetAll()
    for i = 1, #actors do
      local actor = actors[i]
      local npc = actor and actor:IsAlive() and actor:GetNPC()
      if IsValid(npc) and not npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
        local actor_data = actor:GetData()
        if actor_data.regeneration then
          actor._last_regeneration_update_time = actor._last_regeneration_update_time or 0
          if actor._last_regeneration_update_time < CurTime() then
            local regeneration_time = actor_data.regeneration_time or 1
            local max_health = actor_data.regeneration_max_health or npc:GetMaxHealth()
            local current_health = npc:Health()
            if current_health < max_health then npc:SetHealth(math.min(current_health + 1, max_health)) end
            actor._last_regeneration_update_time = CurTime() + regeneration_time
          end
        end
      end

      yield()
    end

    yield()
  end
end)
