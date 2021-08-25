function bgNPC:SetStateAction(state_name, group_name, data)
   bgNPC.state_actions[state_name] = data
   bgNPC.state_actions_groups[state_name] = group_name
end

function bgNPC:GetStateGroupName(state_name)
   return bgNPC.state_actions_groups[state_name] or 'none'
end

function bgNPC:CallStateAction(state_name, func_name, ...)
   local action = bgNPC.state_actions[state_name]
   if not action then return end

   local func = action[func_name]
   if not func then return end

   return func(...)
end

function bgNPC:StateActionExists(state_name, func_name)
   local action = bgNPC.state_actions[state_name]
   if not action then return false end

   local func = action[func_name]
   if not func then return false end
   
   return true
end

timer.Create('BGN_StateMachineController', 5, 0, function()
   if timer.Exists('BGN_StateMachine') then return end

   MsgN('[Background NPCs] Starting the state machine')

   timer.Create('BGN_StateMachine', 1, 0, function()
      local actors = bgNPC:GetAll()
      for i = 1, #actors do
         local actor = actors[i]
         if actor and actor:IsAlive() then
            local state_name = actor:GetState()
            local state_data = actor:GetStateData()
            bgNPC:CallStateAction(state_name, 'update', actor, state_name, state_data)
         end
      end
   end)
end)