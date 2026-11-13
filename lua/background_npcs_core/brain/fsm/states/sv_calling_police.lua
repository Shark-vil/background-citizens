local table_RandomBySeq = bgNPC.Table.Random
--
local asset = bgNPC.Modules.Get('wanted')
local cvar_bgn_enable_wanted_mode = GetConVar('bgn_enable_wanted_mode')
local phone_911_sounnds = {Sound('background_npcs/calling_police/911/1.wav'), Sound('background_npcs/calling_police/911/2.wav'), Sound('background_npcs/calling_police/911/3.wav'), Sound('background_npcs/calling_police/911/4.wav'),}
local phone_beep_sounnds = {Sound('background_npcs/calling_police/bepp/1.wav'), Sound('background_npcs/calling_police/bepp/2.wav'), Sound('background_npcs/calling_police/bepp/3.wav'), Sound('background_npcs/calling_police/bepp/4.wav'), Sound('background_npcs/calling_police/bepp/5.wav'), Sound('background_npcs/calling_police/bepp/6.wav'), Sound('background_npcs/calling_police/bepp/7.wav'), Sound('background_npcs/calling_police/bepp/8.wav'),}
-- @return boolean the entity is already wanted, or at least one living officer has it as an enemy or a target: no need to report it
function bgNPC.PoliceKnows(enemy)
  if asset:HasWanted(enemy) then return true end
  for _, police in ipairs(bgNPC.Actors.GetByTeam('police')) do
    if police:IsAlive() and (police:HasEnemy(enemy) or police:HasTarget(enemy)) then return true end
  end
  return false
end

local function IsValidWantedMode()
  return cvar_bgn_enable_wanted_mode:GetBool()
end

-- Within this distance of a player at most MAX_CALLERS actors phone the police at once.
local MAX_CALLERS = 2
local CALLER_RADIUS_SQR = 2500 ^ 2
local function TooManyCallers(actor)
  local pos = actor:GetPos()
  for _, ply in ipairs(player.GetHumans()) do
    if ply:GetPos():DistToSqr(pos) <= CALLER_RADIUS_SQR then
      local callers = 0
      for _, other in ipairs(bgNPC.Actors.GetAll()) do
        if other ~= actor and other:HasState('calling_police') and other:GetPos():DistToSqr(ply:GetPos()) <= CALLER_RADIUS_SQR then callers = callers + 1 end
      end

      if callers >= MAX_CALLERS then return true end
    end
  end
  return false
end

bgNPC.States.Register('calling_police', 'danger', {
  pre_start = function(actor)
    if not IsValidWantedMode() or TooManyCallers(actor) then return 'fear' end
    local enemy = actor:GetEnemy()
    if IsValid(enemy) and bgNPC.PoliceKnows(enemy) then return 'fear' end
  end,
  stop = function(actor) actor:StopStaticSequence() end,
  update = function(actor)
    if actor:HasNoEnemies() then
      actor:RandomState()
      return
    end

    local currentEnemy = actor:GetEnemy()
    local reaction = actor:GetReactionForDamage()
    reaction = reaction == 'calling_police' and 'fear' or reaction
    if not IsValidWantedMode() or not IsValid(currentEnemy) then
      actor:SetState(reaction)
      return
    end

    local npc = actor:GetNPC()
    local npc_index = npc:EntIndex()
    -- 90000 = 300 ^ 2
    if npc:GetPos():DistToSqr(currentEnemy:GetPos()) < 90000 then
      local rnd = math.random(0, 100)
      if rnd > 80 then actor:CallForHelp(currentEnemy) end
      actor:SetState('fear')
      return
    end

    local data = actor:GetStateData()
    if data.calling_time == nil then
      data.calling_time = CurTime() + math.random(7, 15)
    else
      if data.calling_time < CurTime() then
        for _, enemy in pairs(actor.enemies) do
          if IsValid(enemy) and not actor:HasTeam(enemy) and not bgNPC.PoliceKnows(enemy) and not hook.Run('BGN_PreCallingPolice', actor, enemy) then
            asset:AddWanted(enemy)
            local operator = table_RandomBySeq(phone_911_sounnds)
            EmitSound(operator, npc:GetPos(), npc_index, CHAN_AUTO, 1, 140, 0, 100)
            -- the caller answers the operator once the clip ends
            timer.Simple(math.max(SoundDuration(operator), 2), function() actor:Voice('call_911') end)
          end
        end

        if not hook.Run('BGN_PostCallingPolice', actor) then actor:SetState('fear') end
      else
        if not actor:HasSequence('Crouch_IdleD') then
          actor:SetNextSequence('Crouch_To_Stand')
          actor:PlayStaticSequence('Crouch_IdleD', true, 8)
        end

        data.btn_click_delay = data.btn_click_delay or 0
        if data.btn_click_delay < CurTime() then
          EmitSound(table_RandomBySeq(phone_beep_sounnds), npc:GetPos(), npc_index, CHAN_AUTO, 1, 120, 0, 100)
          data.btn_click_delay = CurTime() + math.random(.3, 1.2)
        end
      end
    end
  end
})
