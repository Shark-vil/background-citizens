local sync_data = {}

local function thread_method()
   for _, ply in ipairs(player.GetAll()) do
      sync_data[ply] = sync_data[ply] or {}

      for i = #sync_data[ply], 1, -1 do
         local ent = sync_data[ply][i]
         if not IsValid(ent) then
            table.remove(sync_data[ply], i)
         end
      end
      
      for _, ent in ipairs(ents.FindInPVS(ply)) do
         local actor = bgNPC:GetActor(ent)
         if actor ~= nil and not table.HasValue(sync_data[ply], ent) and ply:TestPVS(ent) then
            snet.Invoke('bgn_add_actor_from_client', ply, actor:GetType(), ent)

            timer.Create('bgn_sync_pvs_actor_' .. actor.uid .. '_player_' .. ply:UserID(), 0.5, 1, function()
               if not IsValid(ent) then return end

               snet.IsValidForClient(ply, function(ply, success)            
                  if not success then
                     table.RemoveByValue(sync_data[ply], ent)
                  else
                     actor:SyncData()
                  end
               end, 'actor', nil, nil, ent)
            end)

            table.insert(sync_data[ply], ent)
         end
      end

      coroutine.yield()
   end

   return coroutine.yield()
end

local thread
hook.Add("Think", "BGN_PlayersSyncNPCByRadius", function()
   if not thread or not coroutine.resume(thread) then
		thread = coroutine.create(thread_method)
		coroutine.resume(thread)
	end
end)