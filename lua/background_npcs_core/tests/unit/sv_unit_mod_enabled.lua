snet.Callback('bgn_sv_unit_test_mod_enabled', function(ply)
   if GetConVar('bgn_enable'):GetBool() then
      ply:ConCommand('bgn_unit_test_add_result "Addon functionality is active" "yes"')
   else
      ply:ConCommand('bgn_unit_test_add_result "Addon functionality is active" "no"')
   end
end).Protect().Register()