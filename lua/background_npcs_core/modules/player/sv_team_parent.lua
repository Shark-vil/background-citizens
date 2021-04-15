local ASSET = {}

function ASSET:HasTeam(ply, actor)
   if not actor.isBgnClass or not ply:IsPlayer() then return false end
   
   local team_id = ply:Team()
   for team_name, data in pairs(bgNPC.cfg.player.team_parents) do
      if actor:HasTeam(team_name) and array.HasValue(data, team_id) then return true end
   end

   local ply_team_name = team.GetName(team_id)
   for team_name, data in pairs(bgNPC.cfg.player.team_names_parents) do
      if actor:HasTeam(team_name) and array.HasValue(data, ply_team_name) then return true end
   end

   return false
end

function ASSET:HasUserGroup(ply, actor)
   if not actor.isBgnClass or not ply:IsPlayer() then return false end
   
   local group_id = ply:GetUserGroup()
   for team_name, data in pairs(bgNPC.cfg.player.usergroup_parents) do
      if actor:HasTeam(team_name) and array.HasValue(data, group_id) then return true end
   end

   return false
end

function ASSET:HasParent(ply, actor)
   if ply.bgn_team and actor:HasTeam(ply.bgn_team) then return true end
   if self:HasTeam(ply, actor) or self:HasUserGroup(ply, actor) then return true end
   return false
end

list.Set('BGN_Modules', 'team_parent', ASSET)