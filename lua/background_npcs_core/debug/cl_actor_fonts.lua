local Inspector = bgNPC.DebugInspector
Inspector.font = 'BGN_DebugText'
Inspector.title_font = 'BGN_DebugTitle'
local function UpdateFonts()
  local scale = math.Clamp(ScrH() / 900, 0.9, 1.6) * GetConVar('bgn_cl_debug_text_scale'):GetFloat()
  local size = math.Round(20 * scale)
  Inspector.line_height = size + math.Round(4 * scale)
  surface.CreateFont(Inspector.font, {
    font = 'Tahoma',
    size = size,
    weight = 500,
    extended = true
  })

  surface.CreateFont(Inspector.title_font, {
    font = 'Tahoma',
    size = math.Round(24 * scale),
    weight = 700,
    extended = true
  })

  Inspector.report_source = nil
  if Inspector.OnSnapshot and Inspector.detail then Inspector.OnSnapshot(Inspector.detail) end
end

UpdateFonts()
hook.Add('OnScreenSizeChanged', 'BGN_Debug_Fonts', UpdateFonts)
cvars.AddChangeCallback('bgn_cl_debug_text_scale', UpdateFonts, 'BGN_Debug_Fonts')
function Inspector.WrapLines(lines, width)
  surface.SetFont(Inspector.font)
  local wrapped = {}
  for _, text in ipairs(lines) do
    local line = ''
    for word in text:gmatch('%S+') do
      local candidate = line == '' and word or line .. ' ' .. word
      if line ~= '' and surface.GetTextSize(candidate) > width then
        wrapped[#wrapped + 1] = line
        line = word
      else
        line = candidate
      end
    end

    wrapped[#wrapped + 1] = line
  end
  return wrapped
end
