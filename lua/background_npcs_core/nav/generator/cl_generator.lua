-- Progress of the node generator (see sv_generator.lua).
bgNPC.Net.Receive('bgn_nav_generator_progress', function(_, text)
  notification.AddProgress('bgn_nav_generator', '[Background NPCs] ' .. tostring(text))
  timer.Create('bgn_nav_generator_progress_hide', 3, 1, function() notification.Kill('bgn_nav_generator') end)
end)
