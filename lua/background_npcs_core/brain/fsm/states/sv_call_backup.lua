--[[
	call_backup: an outnumbered officer (GOAP fact "outnumbered") calls backup on the radio, from cover when it
	found one. Up to MAX_OFFICERS free officers on foot within SEARCH_DIST take its enemy and come (defense runs
	to a far enemy), and with wanted mode on every enemy of the officer becomes wanted, so all the police and
	pursuit cars join. After CALL_TIME it fights.
	actor.backup_until is the GOAP fact "backup_called" (brain/goap/sv_goap_actions.lua).
	State data: { enemy = <entity> }.
--]]
local SEARCH_DIST_SQR = 4000 ^ 2
local MAX_OFFICERS = 3
local CALL_TIME = 2
local BACKUP_TIME = 60 -- one call per officer this often
local cvar_wanted_mode = GetConVar('bgn_enable_wanted_mode')
local wanted
-- @return table the nearest free officers on foot
local function FreeOfficers(actor)
  local origin, list = actor:GetPos(), {}
  for _, officer in ipairs(bgNPC.Actors.GetByTeam('police')) do
    if officer ~= actor and officer:IsAlive() and not officer:InVehicle() and officer:HasNoEnemies() then
      local dist = officer:GetPos():DistToSqr(origin)
      if dist < SEARCH_DIST_SQR then
        list[#list + 1] = {
          officer = officer,
          dist = dist
        }
      end
    end
  end

  table.SortByMember(list, 'dist', true)
  return list
end

-- the radio call puts the officer's targets on the wanted list
local function MarkWanted(actor)
  wanted = wanted or bgNPC.Modules.Get('wanted')
  if not wanted or not cvar_wanted_mode:GetBool() then return end
  for _, enemy in ipairs(actor.enemies) do
    local enemy_actor = IsValid(enemy) and bgNPC.Actors.Get(enemy)
    if IsValid(enemy) and not (enemy_actor and enemy_actor:HasTeam('police')) then
      if wanted:HasWanted(enemy) then
        wanted:GetWanted(enemy):UpdateWanted()
      else
        wanted:AddWanted(enemy)
      end
    end
  end
end

bgNPC.States.Register('call_backup', 'danger', {
  pre_start = function(actor, _, data)
    data.enemy = actor:GetEnemy()
    if not IsValid(data.enemy) then
      actor.backup_until = CurTime() + BACKUP_TIME -- don't ask again right away
      return 'defense'
    end
  end,
  start = function(actor, _, data)
    data.done = CurTime() + CALL_TIME
    actor:Voice('police_backup', 'npc/metropolice/vo/officerneedsassistance.wav')
    actor:GetBody():StopMoving()
    local list = FreeOfficers(actor)
    for i = 1, math.min(#list, MAX_OFFICERS) do
      local officer = list[i].officer
      officer:AddEnemy(data.enemy)
      officer:ShareEnemyMemory(actor, data.enemy)
      if bgNPC.DebugInspector then bgNPC.DebugInspector.Emit(officer, 'radio', data.enemy, nil, actor:GetNPC(), officer:HasEnemy(data.enemy)) end
      officer:SetState('defense')
    end

    MarkWanted(actor)
  end,
  -- the fact is set only when the call ends: set earlier, GOAP would see it done and cut the call short
  stop = function(actor) actor.backup_until = CurTime() + BACKUP_TIME end,
  update = function(actor, _, data) if not IsValid(data.enemy) or data.done < CurTime() then actor:SetState('defense') end end,
})
