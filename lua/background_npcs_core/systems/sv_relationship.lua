--
local cvar_bgn_ignore_another_npc = GetConVar('bgn_ignore_another_npc')
-- Initialize configured actor relationships without erasing a foreign NPC's own hostility.
local function SetNPCRelationship(actor, another_npc)
  if not actor:IsAlive() then return end
  local actor_npc = actor:GetNPC()
  local another_actor = bgNPC.Actors.Get(another_npc)
  local disposition = D_NU
  if another_actor and (bgNPC.Modes.IsPeaceful() or actor:HasTeam(another_actor)) then disposition = D_LI end
  if isfunction(actor_npc.AddEntityRelationship) then actor_npc:AddEntityRelationship(another_npc, actor:GetRelationship(another_npc) or disposition, 99) end
  if another_actor then
    if isfunction(another_npc.AddEntityRelationship) then another_npc:AddEntityRelationship(actor_npc, another_actor:GetRelationship(actor_npc) or disposition, 99) end
  elseif actor_npc:IsNextBot() and another_npc:IsNPC() and isfunction(another_npc.Disposition) and isfunction(another_npc.AddEntityRelationship) then
    local relation = D_NU
    if not bgNPC.Modes.IsPeaceful() and not cvar_bgn_ignore_another_npc:GetBool() then relation = bgNPC.NextBotBody.GetPlayersDisposition(another_npc, player.GetAll()) end
    another_npc:AddEntityRelationship(actor_npc, relation, 100)
  end
end

local function RebuildActorsRelationship(actor)
  if not actor or not actor:IsAlive() then return end
  bgNPC.Util.Log('RebuildActorsRelationship', 'Relationship')
  for _, another_actor in ipairs(bgNPC.Actors.GetAll()) do
    if another_actor and another_actor:IsAlive() and another_actor ~= actor then SetNPCRelationship(actor, another_actor:GetNPC()) end
  end
end

cvars.AddChangeCallback('bgn_peaceful_mode', function()
  timer.Simple(.1, function()
    local entities = ents.GetAll()
    for _, actor in ipairs(bgNPC.Actors.GetAll()) do
      actor:RemoveAllEnemies()
      actor:SetState('walk', nil, true)
      RebuildActorsRelationship(actor)
      for _, npc in ipairs(entities) do
        if npc and npc:IsNPC() and not npc.isBgnActor then SetNPCRelationship(actor, npc) end
      end
    end
  end)
end, 'bgn_peaceful_mode')

cvars.AddChangeCallback('bgn_friend_mode', function(_, old_value, new_value)
  timer.Simple(.1, function()
    local new_value_number = tonumber(new_value)
    if new_value_number == 0 then return end
    local asset = bgNPC.Modules.Get('wanted')
    for _, ply in ipairs(player.GetAll()) do
      if asset:HasWanted(ply) then asset:RemoveWanted(ply) end
      for _, actor in ipairs(bgNPC.Actors.GetAll()) do
        actor:RemoveEnemy(ply)
      end
    end
  end)
end, 'bgn_friend_mode')

-- hook.Add('BGN_InitActor', 'BGN_RemoveActorTargetFixer', function(actor)
-- 	RebuildActorsRelationship(actor)
-- end)
local function SetPlayersRelationship(actor)
  if not actor:IsAlive() or actor:InVehicle() then return end
  local npc = actor:GetNPC()
  -- Sets neutral relations for all existing players
  if isfunction(npc.AddEntityRelationship) then
    for _, ply in ipairs(player.GetAll()) do
      npc:AddEntityRelationship(ply, actor:GetRelationship(ply) or D_NU, 99)
      -- if cvar_bgn_debug:GetBool() then
      -- 	bgNPC.Util.Log(
      -- 		string.format('Player relationship: %q > %q : %s',
      -- 			tostring(npc),
      -- 			tostring(ply),
      -- 			tostring(log_disposition[npc:Disposition(ply)])
      -- 		),
      -- 		'Relationship'
      -- 	)
      -- end
    end
  end
end

hook.Add('BGN_InitActor', 'BGN_SetPlayersRelationship', SetPlayersRelationship)
hook.Add('BGN_ActorEntityChanged', 'BGN_SetPlayersRelationship', SetPlayersRelationship)
-- Sets relationships for all existing NPCs and NextBots in the map
local function SetExistingNPCRelationships(actor)
  if not actor:IsAlive() or actor:InVehicle() then return end
  for _, npc in ipairs(ents.GetAll()) do
    if IsValid(npc) and (npc:IsNPC() or npc:IsNextBot()) then SetNPCRelationship(actor, npc) end
  end
end

hook.Add('BGN_InitActor', 'BGN_AddAnotherNPCToIgnore', SetExistingNPCRelationships)
hook.Add('BGN_ActorEntityChanged', 'BGN_AddAnotherNPCToIgnore', SetExistingNPCRelationships)
-- Poll actual dispositions, including changes made by other addons after initialization.
timer.Create('BGN_SpotHostileNPC', 1, 0, function()
  if bgNPC.Modes.IsPeaceful() or cvar_bgn_ignore_another_npc:GetBool() then return end
  local actors = {}
  for i, actor in ipairs(bgNPC.Actors.GetAll()) do actors[i] = actor end
  local wanted = bgNPC.Modules.Get('wanted')
  for _, ent in ipairs(ents.GetAll()) do
    if IsValid(ent) and not ent:IsPlayer() and not bgNPC.Actors.Get(ent) and bgNPC.Combat.IsAttacker(ent) and ent:Health() > 0 and not bgNPC.Combat.IsIgnored(ent) and isfunction(ent.Disposition) then
      for _, actor in ipairs(actors) do
        if actor:IsAlive() and ent:Disposition(actor:GetNPC()) == D_HT then
          if GetConVar('bgn_enable_wanted_mode'):GetBool() and (actor:HasTeam('residents') or actor:HasTeam('police')) then wanted:AddWanted(ent) end
          if not actor:HasEnemy(ent) and actor:GetNPC():GetPos():DistToSqr(ent:GetPos()) <= 2500 ^ 2 and bgNPC.Vision.HasLineOfSight(actor:GetNPC(), ent, 'hostile') then
            local reaction = actor:GetReactionForProtect(ent)
            if actor.protect_blocked_enemy ~= ent then
              actor:AddEnemy(ent, reaction)
              if actor:EqualStateGroup('calm') then actor:SetState(reaction) end
            end
          end
        end
      end
    end
  end
end)

-- Sets relationships for newly created NPCs and NextBots
hook.Add('OnEntityCreated', 'BGN_AddAnotherNPCToIgnore', function(npc)
  if not npc:IsNPC() and not npc:IsNextBot() then return end
  timer.Simple(.5, function()
    if not IsValid(npc) or npc.isBgnActor then return end
    local actors = bgNPC.Actors.GetAll()
    for i = #actors, 1, -1 do -- backwards: IsAlive() unregisters dead actors from this live list
      local actor = actors[i]
      if actor and actor:IsAlive() then SetNPCRelationship(actor, npc) end
    end
  end)
end)
