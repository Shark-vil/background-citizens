--
local ASSET = {}
local wanted_list = {}
local wanted_time = GetConVar('bgn_wanted_time'):GetFloat()
bgNPC.CVars.OnChange('bgn_wanted_time', function(_, _, newValue)
  wanted_time = tonumber(newValue)
  if SERVER then
    for _, wanted in ipairs(wanted_list) do
      wanted:UpdateWanted()
    end
  end

  bgNPC.Util.Log('New value for "wanted_time" - ' .. tostring(wanted_time), 'Wanted Module Class')
end, 'bgn_wanted_module_cvar_bgn_wanted_time')

function ASSET:Instance(ent)
  local public = {}
  public.target = ent
  public.time_reset = CurTime() + wanted_time
  -- public.time = wanted_time
  public.wait_time = wanted_time
  public.level = 1
  public.level_max = 5
  public.next_kill_update = bgNPC.cfg.wanted.levels[1]
  function public:Rebind(target)
    ent, self.target = target, target
  end

  function public:UpdateWanted(time)
    time = isnumber(time) and time or wanted_time
    self.time_reset = CurTime() + time
    self.wait_time = time
    if SERVER then bgNPC.Net.Send('bgn_module_wanted_UpdateWanted', nil, ent, time) end
  end

  function public:UpdateWaitTime(time)
    self.wait_time = math.Round(time)
    if SERVER and self.time_reset - CurTime() > wanted_time then self.time_reset = CurTime() + wanted_time end
    if SERVER and self.wait_time > wanted_time then self.wait_time = math.Round(wanted_time) end
    if SERVER then bgNPC.Net.Send('bgn_module_wanted_UpdateWaitTime', nil, ent, self.wait_time) end
  end

  function public:SetLevel(level)
    if not isnumber(level) or level <= 0 then
      ASSET:RemoveWanted(ent)
      return
    elseif level > self.level_max then
      level = self.level_max
    end

    self.level = level
    if SERVER then bgNPC.Net.Send('bgn_module_wanted_UpdateLevel', nil, ent, self.level) end
    local cfg_kills = bgNPC.cfg.wanted.levels[self.level]
    self.next_kill_update = bgNPC.Statistics.GetSum(ent) + cfg_kills
  end

  function public:LevelUp()
    if not GetConVar('bgn_wanted_level'):GetBool() then return end
    if self.level + 1 <= self.level_max then
      self.level = self.level + 1
      if SERVER then bgNPC.Net.Send('bgn_module_wanted_UpdateLevel', nil, ent, self.level) end
      local cfg_kills = bgNPC.cfg.wanted.levels[self.level]
      self.next_kill_update = self.next_kill_update + cfg_kills
      hook.Run('BGN_WantedLevelUp', ent, self.next_kill_update)
    end
  end

  function public:LevelDown()
    if self.level > 0 then
      self.level = self.level - 1
      if self.level == 0 then
        ASSET:RemoveWanted(ent)
        hook.Run('BGN_WantedLevelDown', ent, 0)
        return
      elseif SERVER then
        bgNPC.Net.Send('bgn_module_wanted_UpdateLevel', nil, ent, self.level)
      end

      local cfg_kills = bgNPC.cfg.wanted.levels[self.level + 1]
      self.next_kill_update = self.next_kill_update - cfg_kills
      if self.next_kill_update < 0 then self.next_kill_update = 0 end
      hook.Run('BGN_WantedLevelDown', ent, self.level)
    end
  end
  return public
end

function ASSET:AddWanted(ent, time)
  if self:HasWanted(ent) then return end
  -- every source (kills, police calls, damage) ends here: ignored players are never wanted
  if SERVER and (ent.bgn_arrested or bgNPC.Combat.IsIgnored(ent)) then return end
  local actor = SERVER and bgNPC.Actors.Get(ent)
  if actor and actor:HasTeam('medics') then return end
  if SERVER and not ent:IsPlayer() then bgNPC.Modules.Get('player_arrest'):RemoveTarget(ent) end
  local WantedClass = self:Instance(ent)
  if isnumber(time) then
    WantedClass.time_reset = CurTime() + time
    WantedClass.wait_time = time
  end

  table.insert(wanted_list, WantedClass)
  if SERVER then bgNPC.Net.Send('bgn_module_wanted_AddWanted', nil, ent, WantedClass.wait_time) end
  hook.Run('BGN_AddWantedTarget', ent)
  bgNPC.Util.Log('AddWanted - ' .. tostring(ent), 'Module | Wanted')
  return WantedClass
end

function ASSET:RemoveWanted(ent)
  local _, index = self:GetWanted(ent)
  if index == -1 then return false end
  table.remove(wanted_list, index)
  if SERVER then bgNPC.Net.Send('bgn_module_wanted_RemoveWanted', nil, ent) end
  hook.Run('BGN_RemoveWantedTarget', ent)
  bgNPC.Util.Log('RemoveWanted - ' .. tostring(ent), 'Module | Wanted')
  return true
end

function ASSET:ClearAll()
  bgNPC.Util.Log('ClearAll', 'Module | Wanted')
  if SERVER then
    local targets={}
    for _,wanted in ipairs(wanted_list) do targets[#targets+1]=wanted.target end
    for _,target in ipairs(targets) do self:RemoveWanted(target) end
  else wanted_list={} end
end

function ASSET:ClearDeath()
  for i = #wanted_list, 1, -1 do
    local WantedClass = wanted_list[i]
    local target = WantedClass.target
    if not IsValid(target) or target:Health() <= 0 then
      if SERVER then self:RemoveWanted(target) else table.remove(wanted_list,i) end
    end
  end
end

function ASSET:HasWanted(ent)
  if not IsValid(ent) then return false end
  return bgNPC.Table.HasWhere(wanted_list, function(k, v) return v.target == ent end)
end

function ASSET:GetWanted(ent)
  for i = 1, #wanted_list do
    local WantedClass = wanted_list[i]
    if WantedClass.target == ent then return WantedClass, i end
  end
  return nil, -1
end

function ASSET:GetAllWanted()
  return wanted_list
end

hook.Add('BGN_ActorEntityChanged', 'BGN_WantedRebind', function(_, old, npc)
  local wanted = ASSET:GetWanted(old)
  if not wanted then return end
  if ASSET:HasWanted(npc) then
    ASSET:RemoveWanted(old)
  else
    wanted:Rebind(npc)
  end

  if SERVER then
    bgNPC.Net.Send('bgn_module_wanted_AddWanted', nil, npc, math.max(0, wanted.time_reset - CurTime()))
    bgNPC.Net.Send('bgn_module_wanted_UpdateLevel', nil, npc, wanted.level)
  end
end)

hook.Add('PostCleanupMap', 'BGN_WantedModule_ClearWantedListOnCleanupMap', function() ASSET:ClearAll() end)
hook.Add('PlayerDeath', 'BGN_WantedModule_PlayerDeathRemoveWanted', function(ply) if ASSET:HasWanted(ply) then ASSET:RemoveWanted(ply) end end)
timer.Create('BGN_WantedModule_AutoClearDeathTargets', 1, 0, function() ASSET:ClearDeath() end)
list.Set('BGN_Modules', 'wanted', ASSET)
