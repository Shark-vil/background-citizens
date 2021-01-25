bgNPC.cfg.player = bgNPC.cfg.player or {
   usergroup_parents = {},
   team_names_parents = {},
   team_parents = {}
}

local function IS_LOAD_TEAM_CONFIG_VARS()

   bgNPC.cfg.player.usergroup_parents = {
      ['_actor_team_'] = {
         'superadmin',
      },
   }

   bgNPC.cfg.player.team_names_parents = {
      ['_actor_team_'] = {
         'Civil Protection',
      }
   }

   bgNPC.cfg.player.team_parents = {
      ['residents'] = {
         TEAM_POLICE,
      }
   }

end
hook.Add("PreGamemodeLoaded", "BGN_LoadAllowTeamsFromTeamParentModule", IS_LOAD_TEAM_CONFIG_VARS)