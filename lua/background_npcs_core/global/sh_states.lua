local state_actions = {}

function bgNPC:SetStateAction(state_name, data)
   state_actions[state_name] = data
end

function bgNPC:CallStateAction(actor, state_name, state_data, func_name)
   local action = state_actions[state_name]
   if not action then return end

   local func = action[func_name]
   if not func then return end
   
   pcall(function()
      func(actor, state_name, state_data)
   end)
end

timer.Create('BGN_StateMachine', 1, 0, function()
   local actors = bgNPC:GetAll()
   for i = 1, #actors do
      local actor = actors[i]
      if actor:IsAlive() and not actor.system_state_machine_update_stop then
         bgNPC:CallStateAction(actor, actor:GetState(), actor:GetStateData(), 'update')
      end
   end
end)

hook.Add('BGN_SetNPCState', 'BGN_StateMachine_Changes', function(actor, state, data)
   local old_state = actor:GetOldState()
   local old_data = actor:GetOldStateData()
   
   if old_state == 'none' then
      actor.system_state_machine_update_stop = true
      bgNPC:CallStateAction(actor, state, data, 'start')
   elseif state ~= old_state then
      actor.system_state_machine_update_stop = true
      bgNPC:CallStateAction(actor, old_state, old_data, 'stop')
      bgNPC:CallStateAction(actor, state, data, 'start')
   end

   actor.system_state_machine_update_stop = false
end)