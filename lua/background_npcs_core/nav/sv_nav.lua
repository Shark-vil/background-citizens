--[[
	Navigation layer. One active provider answers every point / path query of the addon.

		navmesh    - the map's NavMesh (maps/<map>.nav), areas are the points
		nodegraph  - the map's AI nodes (maps/graphs/<map>.ain)
		custom     - our own node graph (data/background_npcs/graph/<map>.dat), made with the
		             point editor or the generator; old route files are converted on load

	Choice ("bgn_nav_provider auto"): a saved route file (custom graph or old format) always wins,
	then navmesh, then nodegraph, then an empty custom graph (fill it with the generator).
	The engine NavMesh generation is never triggered.

	Hooks:
		BGN_NavProviderChanged(provider)  - after a provider was loaded
--]]
local Nav = bgNPC.Nav or {}
bgNPC.Nav = Nav
local cvar_provider = CreateConVar('bgn_nav_provider', 'auto', {FCVAR_ARCHIVE}, 'Background NPCs: navigation source (auto, navmesh, nodegraph, custom)')
-- ---------------------------------------------------------------------------
-- Provider base
-- ---------------------------------------------------------------------------
local Provider = bgNPC.Class('BGN_NavProvider')
Nav.Provider = Provider
Provider.name = 'none'
function Provider:Load()
  return true
end

function Provider:Count()
  return 0
end

-- @return table list of Vectors
function Provider:GetPointsInRadius(center, radius, link_type, limit)
  return {}
end

-- @return table list of Vectors, every point (or a sample for huge sources)
function Provider:GetAllPoints(link_type)
  return {}
end

-- @return Vector|nil
function Provider:GetRandomPoint(center, radius, link_type)
  local points = self:GetPointsInRadius(center, radius, link_type)
  return points[math.random(#points)]
end

-- @return table|nil list of Vectors from start to goal (excluding start)
function Provider:FindPath(start_pos, goal_pos, link_type)
  return nil
end

-- Can the body walk the whole way to a far point by itself (no waypoints needed)?
function Provider:GetInfo()
  return {
    provider = self.name,
    points = self:Count()
  }
end

-- ---------------------------------------------------------------------------
-- Selection
-- ---------------------------------------------------------------------------
local providers = Nav.providers or {}
Nav.providers = providers
-- @param name string
-- @param cls class derived from Nav.Provider, with static IsAvailable() and HasSavedRoute()
function Nav.RegisterProvider(name, cls)
  cls.name = name
  providers[name] = cls
end

local active = Provider()
function Nav.GetProvider()
  return active
end

function Nav.GetName()
  return active.name
end

local AUTO_ORDER = {'navmesh', 'nodegraph', 'custom'}
-- @return string provider name
function Nav.Resolve()
  local forced = cvar_provider:GetString()
  if providers[forced] and providers[forced].IsAvailable() then return forced end
  local custom = providers.custom
  if custom and custom.HasSavedRoute() then return 'custom' end
  for _, name in ipairs(AUTO_ORDER) do
    local cls = providers[name]
    if cls and cls.IsAvailable() then return name end
  end
  return 'custom'
end

-- Loads the provider chosen by Nav.Resolve (or the given one).
function Nav.Load(name, graph)
  name = name or Nav.Resolve()
  local cls = providers[name]
  if not cls then return false end
  local provider = cls()
  local ok, err
  if name == 'custom' and graph then
    provider.graph, provider.source = graph, 'dupe'
    ok = true
  else
    ok, err = provider:Load()
  end

  if not ok then
    bgNPC.Util.Warning('Navigation provider "' .. name .. '" failed: ' .. tostring(err))
    if name == 'custom' then return false end
    provider = providers.custom()
    local fallback_ok, fallback_err = provider:Load()
    if not fallback_ok then
      bgNPC.Util.Warning('Fallback navigation failed: ' .. tostring(fallback_err))
      return false
    end
  end

  hook.Run('BGN_PreLoadRoutes', game.GetMap()) -- OUTDATED
  if bgNPC.NavGenerator then bgNPC.NavGenerator.Stop() end
  active = provider
  MsgN('[Background NPCs] Navigation: ' .. active.name .. ' (' .. active:Count() .. ' points)')
  hook.Run('BGN_NavProviderChanged', active)
  hook.Run('BGN_PostLoadRoutes', game.GetMap()) -- OUTDATED
  return true
end

-- OUTDATED: old name
bgNPC.LoadRoutes = function() Nav.Load() end
function Nav.GetInfo()
  return active:GetInfo()
end

-- ---------------------------------------------------------------------------
-- Queries (thin wrappers, see bgNPC.Points for the public point API)
-- ---------------------------------------------------------------------------
function Nav.Count()
  return active:Count()
end

-- limit: the most points to return (navmesh caps the result, 64 by default)
function Nav.GetPointsInRadius(center, radius, link_type, limit)
  return active:GetPointsInRadius(center, radius, link_type, limit)
end

function Nav.GetAllPoints(link_type)
  return active:GetAllPoints(link_type)
end

function Nav.GetRandomPoint(center, radius, link_type)
  return active:GetRandomPoint(center, radius, link_type)
end

function Nav.FindPath(start_pos, goal_pos, link_type)
  return active:FindPath(start_pos, goal_pos, link_type)
end

-- NextBot bodies path over the NavMesh themselves, whatever provider gives the points.
function Nav.BodyPathsItself(body)
  return body ~= nil and body:IsNextBot() and navmesh.IsLoaded()
end

-- Does the map have a NavMesh (NextBot bodies need it)?
function Nav.HasNavMesh()
  return navmesh.IsLoaded()
end

hook.Add('InitPostEntity', 'BGN_Nav_Load', function()
  -- NavMesh is loaded a moment after the map entities
  timer.Simple(1, function() Nav.Load() end)
end)

cvars.AddChangeCallback('bgn_nav_provider', function() timer.Create('BGN_Nav_Reload', 0.5, 1, function() Nav.Load() end) end, 'bgn_nav_provider_reload')
bgNPC.Commands.Register('bgn_nav_reload', {
  admin = true,
  help = 'Reloads the navigation provider (auto choice or bgn_nav_provider).',
  server = function() Nav.Load() end,
})

bgNPC.Commands.Register('bgn_nav_info', {
  admin = true,
  help = 'Prints the active navigation provider.',
  server = function(ply)
    local text = '[Background NPCs] ' .. util.TableToJSON(Nav.GetInfo())
    if IsValid(ply) then
      ply:ChatPrint(text)
    else
      MsgN(text)
    end
  end,
})
