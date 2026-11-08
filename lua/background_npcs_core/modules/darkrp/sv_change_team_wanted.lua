hook.Add('playerCanChangeTeam', 'BGN_LockChangeTeamIfPlayerWanted', function(ply)
   if not bgNPC.cfg.darkrp.disableChangeTeamByWanted then return end

   if bgNPC.Modules.Get('wanted'):HasWanted(ply) then
      return false, bgNPC.cfg.darkrp.disableChangeTeamByWantedText
   end
end)