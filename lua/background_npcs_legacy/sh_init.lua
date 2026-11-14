-- Legacy (1.13.x) loader: a trimmed copy of SLibrary first, then the old core.
for _, path in ipairs({'background_npcs_legacy/slib/sh_init.lua', 'background_npcs_legacy/core/sh_init.lua'}) do
  if SERVER then AddCSLuaFile(path) end
  include(path)
end

local text = {'', 'BACKGROUND NPCs  -  LEGACY CORE 1.13.x', '', 'For a DEDICATED SERVER it is recommended to install this addon by', 'copying the files directly into the server "garrysmod/addons" folder,', 'NOT by downloading it from the Steam Workshop.', 'This avoids version conflicts between the Workshop and the legacy core.', '', 'Download:', 'https://github.com/Shark-vil/background-citizens/archive/refs/tags/1.13.7.zip', '',}
local width = 0
for _, line in ipairs(text) do
  width = math.max(width, #line)
end

local border = '+' .. string.rep('-', width + 6) .. '+'
local banner = {border}
for _, line in ipairs(text) do
  banner[#banner + 1] = '|   ' .. line .. string.rep(' ', width - #line) .. '   |'
end

banner[#banner + 1] = border
MsgC(Color(85, 180, 243), '\n' .. table.concat(banner, '\n') .. '\n\n')
