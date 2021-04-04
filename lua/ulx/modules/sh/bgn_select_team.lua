local CATEGORY_NAME = 'Background NPCs'

function ulx.bgnselectteam(calling_ply, target_ply, actor_type)
   if not actor_type or actor_type == 'select team' then return end

   if actor_type == 'not team' then
      ulx.fancyLogAdmin(calling_ply, "#A remove team for #T", target_ply)
      ULib.queueFunctionCall(function(target)
         target.bgn_team = nil
      end, target_ply)
   else
		ulx.fancyLogAdmin(calling_ply, "#A set team for #T (#s)", target_ply, actor_type)
      ULib.queueFunctionCall(function(target, actor_type)
         target.bgn_team = bgNPC.cfg.npcs_template[actor_type].team
      end, target_ply, actor_type)
	end
end

local bgn_select_team = ulx.command(CATEGORY_NAME,
   'ulx bgnselectteam',
   ulx.bgnselectteam,
   '!bgnselectteam'
)

bgn_select_team:addParam{
   type = ULib.cmds.PlayerArg
}

local function getAllTypes()
   local teams = { 'not team' }
   for t, _ in pairs(bgNPC.cfg.npcs_template) do
      table.insert(teams, t)
   end
   return teams
end

bgn_select_team:addParam{ 
   type = ULib.cmds.StringArg,
   hint = "select team",
   ULib.cmds.optional,
   ULib.cmds.takeRestOfLine,
   completes = getAllTypes()
}

bgn_select_team:defaultAccess(ULib.ACCESS_ADMIN)
bgn_select_team:help("Determines the player in the actors team.")