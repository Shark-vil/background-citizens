local function logic_optimization()
   if not GetConVar('bgn_enable'):GetBool() then return end
   
	local bgn_disable_logic_radius = GetConVar('bgn_disable_logic_radius'):GetFloat() ^ 2
   if bgn_disable_logic_radius <= 0 then return end

   local actors = bgNPC:GetAll()
   local players = player.GetAll()
   local pass = 0
   local max_pass = 5

	for i = 1, #actors do
      local actor = actors[i]

      if actor:IsAlive() and not actor:InVehicle() then
         local npc = actor:GetNPC()
         local npc_pos = npc:GetPos()
         local max_dist = nil
         local addIgnoreFlag = true

         for p = 1, #players do
            local ply = players[p]
            if IsValid(ply) then               
               local dist = npc_pos:DistToSqr(ply:GetPos())

               if not max_dist or dist < max_dist then
                  max_dist = dist
               end

               if dist <= bgn_disable_logic_radius or bgNPC:PlayerIsViewVector(ply, npc_pos) then
                  addIgnoreFlag = false
                  break
               end
            end
         end

         coroutine.yield()

         if addIgnoreFlag then
            local delay = npc.bgnIgmoreFlagSwitchDelay or 0
            local time = RealTime()
            if delay < time then
               npc.bgnIgmoreFlagEnabled = not npc.bgnIgmoreFlagEnabled

               if npc.bgnIgmoreFlagEnabled and max_dist >= 1000000 then
                  delay = time + 3
               else
                  delay = time + 1
               end
            end
            npc.bgnIgmoreFlagSwitchDelay = delay
         elseif npc.bgnIgmoreFlagEnabled then
            npc.bgnIgmoreFlagEnabled = false
         end

         if npc.bgnIgmoreFlagEnabled then
            if not npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
               npc:AddEFlags(EFL_NO_THINK_FUNCTION)
            end
         else
            if npc:IsEFlagSet(EFL_NO_THINK_FUNCTION) then
               npc:RemoveEFlags(EFL_NO_THINK_FUNCTION)
            end
         end

         pass = pass + 1
         if pass == max_pass then
            pass = 0
            coroutine.yield()
         end
      end
   end
end

local thread
hook.Add('Think', 'BGN_ActorsLogicOptimization', function()
   if not thread or not coroutine.resume(thread) then
		thread = coroutine.create(logic_optimization)
		coroutine.resume(thread)
	end
end)