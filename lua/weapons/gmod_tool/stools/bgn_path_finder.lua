TOOL.AddToMenu = BGN_LOADER ~= 'legacy'
if not TOOL.AddToMenu then return end
--
TOOL.Category = 'Background NPCs Debug'
TOOL.Name = '#tool.bgn_path_finder.name'
TOOL.PanelIsInit = false
TOOL.Trace = nil
TOOL.Distance = 10000
TOOL.SelectedPointId = -1
TOOL.CurrentTypeId = 1
TOOL.PointToPointLimit = 500
TOOL.Path = {}
TOOL.StartPos = nil
TOOL.EndPos = nil
if SERVER then
  function TOOL:LeftClick()
    if not game.SinglePlayer() then return end
    bgNPC.Net.ToolRPC(self, 'LeftClick')
  end

  function TOOL:RightClick()
    if not game.SinglePlayer() then return end
    bgNPC.Net.ToolRPC(self, 'RightClick')
  end

  function TOOL:Reload()
    if not game.SinglePlayer() then return end
    bgNPC.Net.ToolRPC(self, 'Reload')
  end
else
  function TOOL:GetTrace()
    local ply = self:GetOwner()
    local tr = util.TraceLine({
      start = ply:GetShootPos(),
      endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
      filter = function(ent) if ent ~= ply then return true end end
    })
    return tr
  end

  function TOOL:ClearPoints()
    self.StartPos = nil
    self.EndPos = nil
    self.Path = {}
  end

  function TOOL.BuildCPanel(Panel)
    bgNPC.DebugInspector.ToolControls(Panel)
    Panel:AddControl('Label', {
      ['Text'] = '#tool.bgn_path_finder.pnl.help'
    })
  end

  function TOOL:LeftClick()
    if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
    local tr = self:GetTrace()
    if not tr.Hit then return end
    self.StartPos = tr.HitPos
    surface.PlaySound('buttons/blip1.wav')
  end

  function TOOL:RightClick()
    if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
    if self.StartPos == nil then return end
    local tr = self:GetTrace()
    if not tr.Hit then return end
    self.EndPos = tr.HitPos
    -- Paths are built on the server by the active navigation provider.
    local start_pos = self.StartPos
    bgNPC.NavEditor.RequestPath(start_pos, self.EndPos, function(path)
      table.insert(path, 1, start_pos)
      self.Path = path
    end)

    surface.PlaySound('buttons/blip1.wav')
  end

  function TOOL:Reload()
    if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
    self:ClearPoints()
    surface.PlaySound('common/wpn_denyselect.wav')
  end

  function TOOL:DrawHUD()
    if self.ReportText then bgNPC.DebugInspector.DrawToolReport(self.ReportText) end
  end

  function TOOL:Think()
    if self.LastPath ~= self.Path or self.LastStart ~= self.StartPos then
      self.LastPath, self.LastStart = self.Path, self.StartPos
      bgNPC.DebugInspector.SetToolPath('bgn_path_finder', #self.Path > 0 and self.Path or (self.StartPos and {self.StartPos} or {}))
      local T = bgNPC.DebugInspector.Text
      self.ReportText = T('path_points') .. ': ' .. #self.Path .. ' | ' .. T(self.EndPos and (#self.Path > 1 and 'compatible' or 'no_path') or 'path.help')
    end
  end

  local en_lang = {
    ['tool.bgn_path_finder.name'] = 'Navigation test',
    ['tool.bgn_path_finder.desc'] = '',
    ['tool.bgn_path_finder.0'] = '',
    ['tool.bgn_path_finder.pnl.help'] = 'Left click - start, right click - end. The server builds the path with the active navigation (bgn_nav_info).',
  }

  local ru_lang = {
    ['tool.bgn_path_finder.name'] = 'Поиск пути',
    ['tool.bgn_path_finder.desc'] = '',
    ['tool.bgn_path_finder.0'] = '',
    ['tool.bgn_path_finder.pnl.help'] = 'ЛКМ - начало, ПКМ - конец. Путь строит сервер по активной навигации (bgn_nav_info).',
  }

  local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
  for k, v in pairs(lang) do
    language.Add(k, v)
  end
end
