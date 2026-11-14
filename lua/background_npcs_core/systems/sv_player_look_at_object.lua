bgNPC.Tasks.Add('BGN_Timer_PlayerLookAtObject', function(yield, wait)
  while true do
    for _, ply in ipairs(player.GetAll()) do
      if IsValid(ply) and ply:Alive() then
        local start = ply:EyePos()
        local tr = util.TraceLine({
          start = start,
          endpos = start + ply:EyeAngles():Forward() * 1000,
          filter = ply
        })

        local ent = tr.Entity
        if tr.Hit and IsValid(ent) then
          if ply.bgn_look_at_object ~= ent or not ply.bgn_look_at_object_hook_delay then
            ply.bgn_look_at_object = ent
            ply.bgn_look_at_object_hook_delay = RealTime()
          end

          local observation_time = RealTime() - ply.bgn_look_at_object_hook_delay
          if hook.Run('BGN_PlayerLookAtObject', ply, ent, observation_time) then ply.bgn_look_at_object_hook_delay = RealTime() end
        else
          ply.bgn_look_at_object, ply.bgn_look_at_object_hook_delay = nil, nil
        end
      end

      yield()
    end

    wait(0.1)
  end
end)
