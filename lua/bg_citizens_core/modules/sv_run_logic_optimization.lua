timer.Create('BGN_Timer_NPCOptimizeFlagController', 0.5, 0, function()
   if not GetConVar('bgn_enable'):GetBool() then return end

	local actors = bgNPC:GetAll()

	if #actors == 0 then return end
   
	local bgn_disable_logic_radius = GetConVar('bgn_disable_logic_radius'):GetFloat() ^ 2
   if bgn_disable_logic_radius <= 0 then return end

	for _, actor in ipairs(actors) do
      if not actor.eternal or not actor:IsAlive() then
         goto skip
      end

      if not actor:HasState(bgNPC.cfg.npcs_states['calmly']) then
         goto skip
      end

      local npc = actor:GetNPC()
      local npc_pos = npc:GetPos()
      local addIgnoreFlag = true

      for _, ply in ipairs(player.GetAll()) do
         if IsValid(ply) then               
            local dist = npc_pos:DistToSqr(ply:GetPos())

            if dist <= bgn_disable_logic_radius or bgNPC:PlayerIsViewVector(ply, npc_pos) then
               addIgnoreFlag = false
               break
            end
         end
      end

      if addIgnoreFlag then
         if not npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
            npc:AddEFlags(EFL_NO_THINK_FUNCTION)
         end
      else
         if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
            npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
         end
      end

      ::skip::
   end
end)