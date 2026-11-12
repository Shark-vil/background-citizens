--
bgNPC.States.Register('run_from_danger', 'danger', {
  update = function(actor)
    if actor:HasNoEnemies() then
      actor:RandomState()
      return
    end

    local data = actor:GetStateData()
    local enemy = actor:GetNearEnemy()
    data.call_for_help = data.call_for_help or CurTime() + math.random(20, 30)
    if not IsValid(enemy) or enemy:Health() <= 0 then return end
    -- per entry: the first path is built at once (a shared CheckMoveUpdate timer left the actor standing up to 5 s)
    if (data.next_path_update or 0) > CurTime() then return end
    data.next_path_update = CurTime() + 5
    local npc = actor:GetNPC()
    local npc_pos = npc:GetPos()
    local enemy_pos = enemy:GetPos()
    local dist = npc_pos:DistToSqr(enemy_pos)
    if data.call_for_help < CurTime() then
      actor:CallForHelp(enemy)
      data.call_for_help = CurTime() + math.random(20, 30)
    end

    if math.random(0, 100) <= 5 then actor:FearScream() end
    if dist > 1000000 and (not data.dyspnea_delay or data.dyspnea_delay < CurTime()) then
      actor:SetState('dyspnea_danger')
    elseif dist < 40000 and (enemy:IsPlayer() or bgNPC.Util.Chance(10)) and bgNPC.Util.IsInView(enemy, npc_pos) then
      actor:SetState('fear')
    else
      local min, max = 700, 1000
      local position = actor:GetDistantPointToPoint(enemy_pos, math.random(min, max))
      if position then
        actor:WalkToPos(position, 'run')
      elseif #actor.walkPath == 0 then
        min, max = 500, 1000
        for i = 1, 5 do
          position = npc_pos + Vector(math.random(min, max), math.random(min, max), 0)
          if position:DistToSqr(enemy_pos) > dist then
            actor:WalkToPos(position, 'run')
            if #actor.walkPath ~= 0 then break end
          end
        end
      end
    end
  end,
  not_stop = function(actor, state, data, new_state, new_data) return actor:EnemiesCount() > 0 and not actor:HasStateGroup(new_state, 'danger') end
})
