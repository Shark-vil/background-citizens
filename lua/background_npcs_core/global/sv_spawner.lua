local function FindSpawnLocationProcess(all_players, desiredPosition, limit_pass)
   local spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat()
   local radius_visibility = GetConVar('bgn_spawn_radius_visibility'):GetFloat() ^ 2
   local radius_raytracing = GetConVar('bgn_spawn_radius_raytracing'):GetFloat() ^ 2
   local block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
   local points = bgNPC:GetAllPointsInRadius(desiredPosition, spawn_radius, 'walk')
   local limit_pass = limit_pass or 10
   local current_pass = 0
   local nodePosition

   coroutine.yield()

   points = array.shuffle(points)
   
   coroutine.yield()

   for i = 1, #points do
      local walkNode = points[i]

      nodePosition = walkNode:GetPos()
      
      for p = 1, #all_players do
         local ply = all_players[p]
         local distance = nodePosition:DistToSqr(ply:GetPos())
               
         if distance <= block_radius then goto skip_walk_nodes end
         if distance <= radius_visibility and bgNPC:PlayerIsViewVector(ply, nodePosition) then
            if radius_raytracing == 0 then goto skip_walk_nodes end

            local tr = util.TraceLine({
               start = ply:EyePos(),
               endpos = nodePosition,
               filter = function(ent)
                  if IsValid(ent) and ent ~= ply 
                     and not ent:IsVehicle() and ent:IsWorld() 
                     and not string.StartWith(ent:GetClass(), 'prop_')
                  then
                     return true
                  end
               end
            })

            if not tr.Hit then goto skip_walk_nodes end
         end
      end

      if nodePosition then
         break
      end

      ::skip_walk_nodes::

      nodePosition = nil
      
      current_pass = current_pass + 1
      if current_pass == limit_pass then
         coroutine.yield()
         current_pass = 0
      end
   end

   if not GetConVar('bgn_enable'):GetBool() then return coroutine.yield() end
   return coroutine.yield(nodePosition)
end

local hooks_active = {}
function bgNPC:FindSpawnLocation(spawner_id, desiredPosition, limit_pass, action)
   local hook_name = 'BGN_SpawnerThread_' .. spawner_id
   if hooks_active[hook_name] then return end
   if not action and not isfunction(action) then return end
   
   hooks_active[hook_name] = true

   local all_players = player.GetAll()

   if not desiredPosition then
      local ply = array.Random(all_players)
      desiredPosition = ply:GetPos()
   end

   if not desiredPosition then return end

   local thread = coroutine.create(FindSpawnLocationProcess)
   local isDead = false

   hook.Add("Think", hook_name, function()
      if isDead or coroutine.status(thread) == 'dead' then
         hook.Remove("Think", hook_name)
         hooks_active[hook_name] = false
      else
         local _, nodePosition = coroutine.resume(thread, all_players, desiredPosition, limit_pass)
         if nodePosition and isvector(nodePosition) then
            action(nodePosition)
            isDead = true
         end
      end
   end)
end

function bgNPC:SpawnActor(npcType, desiredPosition, enableSpawnEffect)
   if player.GetCount() == 0 then return end

   local npcData = bgNPC:GetActorConfig(npcType)
   local is_many_classes = false
   local npc_class
   
   if istable(npcData.class) then
      npc_class = array.Random(npcData.class)
      is_many_classes = true
   else
      npc_class = npcData.class
   end
   
   if hook.Run('BGN_OnValidSpawnActor', npcData, npc_class, desiredPosition) then
      return
   end

   local newNpcData, newNpcClass = hook.Run('BGN_OverrideSpawnData', 
      npcType, npcData, npc_class)

   if newNpcData then npcData = newNpcData end
   if newNpcClass then npc_class = newNpcClass end

   local npc = ents.Create(npc_class)
   npc:SetPos(desiredPosition)
   
   --[[
      ATTENTION! Be careful, this hook is called before the NPC spawns. 
      If you give out a weapon or something similar, it will crash the game!
   --]]
   if hook.Run('BGN_PreSpawnActor', npc, npcType, npcData) then
      if IsValid(npc) then npc:Remove() end
      return
   end

   npc:SetSpawnEffect(enableSpawnEffect or false)
   npc:Spawn()
   npc:SetOwner(game.GetWorld())
   npc:Activate()
   npc:PhysWake()

   hook.Run('BGN_PostSpawnActor', npc, npcType, npcData)

   if npcData.models then
      local model

      if is_many_classes and npcData.models[npc_class] then
         model = array.Random(npcData.models[npc_class])
      elseif #npcData.models ~= 0 then
         model = array.Random(npcData.models)
      end

      if model and util.IsValidModel(model) then
         -- Backward compatibility with the old version of the config
         npcData.default_models = npcData.default_models or npcData.defaultModels

         if not npcData.default_models or (npcData.default_models and math.random(0, 10) <= 5) then
            if not hook.Run('BGN_PreSetActorModel', model, npc, npcType, npcData) then
               npc:SetModel(model)
            end
         end
      end
   end

   -- Backward compatibility with the old version of the config
   npcData.random_skin = npcData.random_skin or npcData.randomSkin

   if npcData.random_skin then
      local skin = math.random(0, npc:SkinCount())
      
      if not hook.Run('BGN_PreSetActorSkin', skin, npc, npcType, npcData) then
         npc:SetSkin(math.random(0, npc:SkinCount()))
      end
   end

   -- Backward compatibility with the old version of the config
   npcData.random_bodygroups = npcData.random_bodygroups or npcData.randomBodygroups

   if npcData.random_bodygroups then
      for _, bodygroup in ipairs(npc:GetBodyGroups()) do
         local id = bodygroup.id
         local value = math.random(0, npc:GetBodygroupCount(id))

         if not hook.Run('BGN_PreSetActorBodygroup', id, value, npc, npcType, npcData) then
            npc:SetBodygroup(id, value)
         end
      end
   end

   local actor = BGN_ACTOR:Instance(npc, npcType, npcData)
   bgNPC:AddNPC(actor)

   snet.Create('bgn_add_actor_from_client', npc, npcType, actor.uid).InvokeAll()
   
   actor:RandomState()
   hook.Run('BGN_InitActor', actor)

   return actor
end