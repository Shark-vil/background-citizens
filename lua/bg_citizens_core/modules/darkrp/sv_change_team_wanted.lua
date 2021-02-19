hook.Add("playerCanChangeTeam", "BGN_LockChangeTeamIfPlayerWanted", function(ply)
   if not bgNPC.cfg.darkrp.disableChangeTeamByWanted then return end

   if bgNPC:GetModule('wanted'):HasWanted(ply) then
      return false, bgNPC.cfg.darkrp.disableChangeTeamByWantedText
   end
end)