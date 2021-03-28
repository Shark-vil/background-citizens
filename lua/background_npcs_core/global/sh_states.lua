local state_actions = {}

function bgNPC:SetStateAction(state_name, data)
   state_actions[state_name] = data
end

function bgNPC:CallStateAction(actor, state_name, func_name)
   local state_data = state_actions[state_name]
   if not state_data then return end

   local func = state_data[func_name]
   if not func then return end
   
   pcall(function()
      func(actor, state_name)
   end)
end

timer.Create('BGN_StateMachine', 1, 0, function()
   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:IsAlive() and not actor.system_state_machine_update_stop then
         bgNPC:CallStateAction(actor, actor:GetState(), 'update')
      end
   end
end)

hook.Add('BGN_SetNPCState', 'BGN_StateMachine_Changes', function(actor, state)
   local old_state = actor:GetOldState()
   
   if old_state == 'none' then
      actor.system_state_machine_update_stop = true
      bgNPC:CallStateAction(actor, state, 'start')
   elseif state ~= old_state then
      actor.system_state_machine_update_stop = true
      bgNPC:CallStateAction(actor, old_state, 'stop')
      bgNPC:CallStateAction(actor, state, 'start')
   end

   actor.system_state_machine_update_stop = false
end)