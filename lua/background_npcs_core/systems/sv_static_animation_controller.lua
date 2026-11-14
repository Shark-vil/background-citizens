--
-- timer.Create('BGN_ActorAnimationController', .1, 0, function()
hook.Add('Think', 'BGN_ActorAnimationController', function()
  local actors = bgNPC.Actors.GetAll()
  for i = 1, #actors do
    local actor = actors[i] -- nil: an actor removed earlier in this pass shortened the list
    -- runs every tick for every actor: the field check first, IsAlive only for the few animated ones
    if actor and actor.is_animated and actor:IsAlive() then
      local npc = actor:GetNPC()
      -- frozen AI: under SCHED_SLEEP the engine drops the script state every ~0.3 s and runs its own
      -- schedule for a tick, the NPC flickers between that and the sequence. Set once, not every tick
      if isfunction(npc.SetSchedule) and not npc:IsCurrentSchedule(SCHED_NPC_FREEZE) then
        npc:SetNPCState(NPC_STATE_SCRIPT)
        npc:SetSchedule(SCHED_NPC_FREEZE)
      end

      local sequence = actor.anim_sequence
      if isnumber(sequence) then
        if npc:GetSequence() ~= sequence then
          -- taken anyway (a schedule set by someone else): back on the same frame, not from the start
          npc:ResetSequence(sequence)
          npc:SetCycle(actor.anim_cycle or 0)
        elseif actor:IsLoopSequence() and npc:GetCycle() >= 0.98 then
          npc:ResetSequence(sequence) -- a one-shot sequence played in a loop: again
          npc:SetCycle(0)
        end

        actor.anim_cycle = npc:GetCycle()
      end

      if actor:IsLoopSequence() then
        if actor:IsSequenceLoopFinished() then
          hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
          if not actor:PlayNextStaticSequence() then actor:ResetSequence() end
        end
      elseif actor:IsSequenceFinished() then
        hook.Run('BGN_FinishNPCAnimation', actor, actor.anim_name)
        if not actor:PlayNextStaticSequence() then actor:ResetSequence() end
      end
    end
  end
end)

-- An NPC frozen for an animation (healing, arresting, talking...) never dies: it stays alive-looking in its pose.
-- The freeze is dropped just before a lethal hit, so the engine runs the usual death.
hook.Add('EntityTakeDamage', 'BGN_ActorAnimationRelease', function(npc, dmginfo)
  if not npc:IsNPC() or dmginfo:GetDamage() < npc:Health() then return end
  local actor = bgNPC.Actors.Get(npc)
  if not actor or not actor:IsAnimationPlayed() then return end
  npc:SetNPCState(NPC_STATE_IDLE)
  npc:ClearSchedule()
end)
