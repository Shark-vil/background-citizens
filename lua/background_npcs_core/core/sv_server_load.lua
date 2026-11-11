--[[
	Server load. Overload stops ghost handoffs from exceeding type limits. Existing actors still obey
	the unseen timeout and protection flags in the remover:
	- lagging: in a second of real time fewer than LAG_RATIO of the ticks the tickrate promises ran (the server
	  can't keep up); counts LAG_HOLD seconds after the last slow second, so one hitch doesn't flicker it;
	- critical mass: more actors than CRITICAL_FACTOR times the sum of the active types' limits.
--]]
local ServerLoad = {}
bgNPC.ServerLoad = ServerLoad
local WINDOW = 1
local LAG_RATIO = 0.8
local LAG_HOLD = 3
local PAUSE_TIME = 5 -- a longer window had no ticks because of a pause (single player menu, hibernation)
local CRITICAL_FACTOR = 2
local ticks, window_start, lag_until = 0, SysTime(), 0
-- @return boolean the window ran too few ticks
function ServerLoad.IsSlowWindow(tick_count, elapsed, tick_interval)
  return tick_count < elapsed / tick_interval * LAG_RATIO
end

hook.Add('Tick', 'BGN_ServerLoad', function()
  ticks = ticks + 1
  local now = SysTime()
  local elapsed = now - window_start
  if elapsed < WINDOW then return end
  if elapsed < PAUSE_TIME and ServerLoad.IsSlowWindow(ticks, elapsed, engine.TickInterval()) then lag_until = now + LAG_HOLD end
  ticks, window_start = 0, now
end)

function ServerLoad.IsLagging()
  return SysTime() < lag_until
end

function ServerLoad.IsCriticalMass()
  local limit = 0
  for actor_type in pairs(bgNPC.cfg.actors) do
    if bgNPC.Config.IsTypeActive(actor_type) then limit = limit + bgNPC.Config.GetTypeLimit(actor_type) end
  end
  return #bgNPC.Actors.GetAll() > limit * CRITICAL_FACTOR
end

function ServerLoad.IsOverloaded()
  return ServerLoad.IsLagging() or ServerLoad.IsCriticalMass()
end

bgNPC.Test.Add('server_load', function(check)
  local interval = 1 / 66
  check(not ServerLoad.IsSlowWindow(66, 1, interval), 'a full second of ticks is no lag')
  check(not ServerLoad.IsSlowWindow(56, 1, interval), 'a few missing ticks are no lag')
  check(ServerLoad.IsSlowWindow(40, 1, interval), 'a third of the ticks missing is a lag')
  check(ServerLoad.IsSlowWindow(70, 1.5, interval), 'the window length counts')
end)
