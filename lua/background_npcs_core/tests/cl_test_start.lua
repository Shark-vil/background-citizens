concommand.Add('bgn_unit_tests_start', function()
   if not bgNPC.unit or not bgNPC.unit.TestsList then return end
   bgNPC.unit.TestsList:Clear()

   snet.Invoke('bgn_sv_unit_test_mod_enabled')
   snet.Invoke('bgn_sv_unit_test_exist_nodes')
end)