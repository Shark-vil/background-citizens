bgNPC.cfg.player = {}

-- Link a player's group to a actor team
bgNPC.cfg.player.usergroup_parents = {
   ['_actor_team_'] = {
      'superadmin',
   },
}

-- Link a player's team by name to a actor team
bgNPC.cfg.player.team_names_parents = {
   ['_actor_team_'] = {
      'Civil Protection',
   }
}

-- Link a player's team to a actor team
bgNPC.cfg.player.team_parents = {
   ['residents'] = {
      TEAM_POLICE,
      TEAM_CHIEF,
      TEAM_MAYOR,
   },
   ['bandits'] = {
      TEAM_GANG,
   }
}