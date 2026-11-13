-- The core choice lives in data/background_npcs/loader.txt ('core' or 'legacy'), set by the "bgn_loader" command
-- (autocomplete) and applied on map load. bgn_loader_active only tells clients what the server loaded.
local LOADER_FILE = 'background_npcs/loader.txt'
local active = CreateConVar('bgn_loader_active', 'core', FCVAR_REPLICATED, 'Core loaded by the server (set automatically)')
if SERVER then
  file.CreateDir('background_npcs')
  active:SetString(string.Trim(file.Read(LOADER_FILE, 'DATA') or '') == 'legacy' and 'legacy' or 'core')
end

BGN_LOADER = active:GetString() == 'legacy' and 'legacy' or 'core'
local function autocomplete(cmd, args)
  local typed = string.lower(string.Trim(args))
  local list = {}
  for _, name in ipairs({'core', 'legacy'}) do
    if string.StartWith(name, typed) then list[#list + 1] = cmd .. ' ' .. name end
  end
  return list
end

if SERVER then
  util.AddNetworkString('bgn_loader_set')
  local function set_loader(ply, value)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    value = string.lower(value or '')
    if value == 'core' or value == 'legacy' then
      file.Write(LOADER_FILE, value)
      MsgN('[Background NPCs] Loader set to "' .. value .. '". Restart the map to apply.')
    else
      MsgN('[Background NPCs] Loader: ' .. BGN_LOADER .. '. Usage: bgn_loader core|legacy')
    end
  end

  concommand.Add('bgn_loader', function(ply, _, args) set_loader(ply, args[1]) end, autocomplete)
  net.Receive('bgn_loader_set', function(_, ply) set_loader(ply, net.ReadString()) end)
else
  -- Defined on the client for autocomplete; forwards to the server.
  concommand.Add('bgn_loader', function(_, _, args)
    net.Start('bgn_loader_set')
    net.WriteString(args[1] or '')
    net.SendToServer()
  end, autocomplete)
end

local init = 'background_npcs_' .. BGN_LOADER .. '/sh_init.lua'
if SERVER then AddCSLuaFile(init) end
include(init)
