--[[
	Point editor: edits the custom route graph (bgNPC.NavEditor.graph) on the client.
	"Load points" pulls the server's graph, "Save points" stores it on the server (custom provider).
	Nodes are referenced by graph ids.
--]]
TOOL.Category = 'Background NPCs Editor'
TOOL.Name = '#tool.bgn_point_editor.name'
TOOL.Distance = 10000
TOOL.Types = {'creator', 'remover', 'linker', 'parents_cleaner'}
TOOL.CurrentTypeId = 1
TOOL.RangePoints = {}
TOOL.SelectedId = nil
TOOL.LinkerId = nil
TOOL.CreateSelectedId = nil
TOOL.LinkFullParents = false
TOOL.LastNodeRemover = false
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
  return
end

local NavEditor = bgNPC.NavEditor
local LINK_DISTANCE_SQR = NavEditor.LINK_DISTANCE ^ 2
local UP_10 = Vector(0, 0, 10)
local UP_20 = Vector(0, 0, 20)
local clr = Color(255, 225, 0, 200)
local clr_green = Color(72, 232, 9, 200)
local clr_link = Color(255, 0, 0)
local clr_link_alpha = Color(255, 0, 0, 50)
local clr_point = Color(255, 23, 23, 200)
local clr_point_notlinks = Color(53, 53, 240, 200)
local clr_good = Color(0, 255, 0, 200)
local clr_bad = Color(255, 0, 0, 200)
local clr_parent = Color(255, 255, 255, 200)
local clr_parent_alpha = Color(255, 255, 255, 50)
local clr_future = Color(79, 224, 183, 200)
local color_text = Color(255, 255, 255)
local color_outline = Color(0, 0, 0)
local hud_font = 'Trebuchet24'
local text_font = 'TargetID'
local function Graph()
  return NavEditor.graph
end

hook.Add('BGN_NavEditorGraphLoaded', 'BGN_TOOL_PointEditorReset', function()
  local tool = bgNPC.Util.GetActivePlayerTool('bgn_point_editor')
  if not tool then return end
  tool.LinkerId = nil
  tool.CreateSelectedId = nil
  tool.SelectedId = nil
end)

function TOOL:GetTraceInfo()
  local ply = self:GetOwner()
  return util.TraceLine({
    start = ply:GetShootPos(),
    endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
    filter = ply,
  })
end

function TOOL:GetCurrentType()
  return self.Types[self.CurrentTypeId]
end

function TOOL:SwitchType()
  self.CurrentTypeId = self.CurrentTypeId % #self.Types + 1
  self.CreateSelectedId = nil
end

function TOOL:IsLookingVector(vec)
  local owner = self:GetOwner()
  local diff = vec - owner:GetShootPos()
  return owner:GetAimVector():Dot(diff) / diff:Length() >= 0.998
end

function TOOL:LeftClick()
  if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
  local graph = Graph()
  local tool_type = self:GetCurrentType()
  local selected = self.SelectedId
  if tool_type == 'creator' then
    if not selected then
      self:AddNode()
    elseif selected == self.CreateSelectedId then
      self.CreateSelectedId = nil
    elseif not self.CreateSelectedId then
      self.CreateSelectedId = selected
    else
      self:AddNode()
    end
  elseif tool_type == 'remover' then
    if self.LastNodeRemover then
      self:RemoveLastNode()
    elseif selected then
      self:RemoveNode(selected)
    end
  elseif tool_type == 'linker' and selected then
    if not self.LinkerId then
      self.LinkerId = selected
      surface.PlaySound('common/wpn_select.wav')
      return
    end

    local a, b = self.LinkerId, selected
    if a ~= b then
      local link_type = not self.LinkFullParents and 'walk' or nil
      if graph:IsLinked(a, b, link_type) then
        graph:Unlink(a, b, link_type)
      elseif graph:GetPos(a):DistToSqr(graph:GetPos(b)) <= LINK_DISTANCE_SQR then
        graph:Link(a, b, link_type)
      end
    end

    self.LinkerId = nil
    surface.PlaySound('common/wpn_denyselect.wav')
  elseif tool_type == 'parents_cleaner' and selected then
    for _, other in ipairs(graph:GetNeighbours(selected)) do
      graph:Unlink(selected, other, not self.LinkFullParents and 'walk' or nil)
    end

    surface.PlaySound('common/wpn_denyselect.wav')
  end
end

function TOOL:RightClick()
  if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
  self.LinkerId = nil
  self.SelectedId = nil
  self:SwitchType()
  surface.PlaySound('buttons/blip1.wav')
end

function TOOL:Reload()
  if not game.SinglePlayer() and not IsFirstTimePredicted() then return end
  local tool_type = self:GetCurrentType()
  if tool_type == 'remover' then
    self.LastNodeRemover = not self.LastNodeRemover
  elseif tool_type == 'linker' or tool_type == 'parents_cleaner' then
    self.LinkFullParents = not self.LinkFullParents
  end

  surface.PlaySound('buttons/blip1.wav')
end

concommand.Add('cl_tool_point_editor_reconstruct_parents', function()
  local tool = bgNPC.Util.GetActivePlayerTool('bgn_point_editor', LocalPlayer())
  if not tool then return end
  local graph = Graph()
  local walk = GetConVar('bgn_tool_point_editor_autoparent'):GetBool()
  -- Plain links are rebuilt, walk links made by hand are kept.
  for id in graph:Nodes() do
    for _, other in ipairs(graph:GetNeighbours(id)) do
      if not graph:IsLinked(id, other, 'walk') then graph:Unlink(id, other) end
    end
  end

  for id in graph:Nodes() do
    NavEditor.AutoLink(graph, id, walk)
  end
end)

-- Collects the visible points around the player 5 times per second.
function TOOL:Think()
  if (self.next_refresh or 0) > RealTime() then return end
  self.next_refresh = RealTime() + 0.2
  local owner = self:GetOwner()
  if not owner:Alive() then return end
  local graph = Graph()
  local shoot_pos = owner:GetShootPos()
  local selected
  local points = {}
  graph:ForEachInRadius(owner:GetPos(), GetConVar('bgn_tool_draw_distance'):GetFloat(), function(id, pos)
    if bgNPC.Vision.PlayerCanSeePos(owner, pos) then
      local behind_wall = util.TraceLine({
        start = shoot_pos,
        endpos = pos,
        mask = MASK_NPCWORLDSTATIC
      }).Hit

      points[#points + 1] = {
        id = id,
        behind_wall = behind_wall
      }

      if not selected and not behind_wall and self:IsLookingVector(pos) then selected = id end
    end
  end)

  self.SelectedId = selected
  self.RangePoints = points
end

-- Points every 250 units between two positions, aligned to the floor when enabled.
function TOOL:AutoCreatePoints(start_pos, end_pos)
  local autoalignment = GetConVar('bgn_tool_point_editor_autoalignment'):GetBool()
  local count = math.floor(start_pos:Distance(end_pos) / 250)
  local points = {}
  local old_z = start_pos.z
  for i = 1, count do
    local output = LerpVector(i / count, start_pos, end_pos)
    if autoalignment then
      local tr = util.TraceLine({
        start = Vector(output.x, output.y, old_z) + Vector(0, 0, 100),
        endpos = output - Vector(0, 0, 500),
        mask = MASK_NPCWORLDSTATIC,
      })

      if not tr.Hit then return {} end
      old_z = output.z
      points[#points + 1] = tr.HitPos + UP_10
    else
      points[#points + 1] = output
    end
  end
  return points
end

function TOOL:LinkNew(id)
  NavEditor.AutoLink(Graph(), id, GetConVar('bgn_tool_point_editor_autoparent'):GetBool())
end

function TOOL:AddNode()
  local tr = self:GetTraceInfo()
  if not tr.Hit then return end
  local graph = Graph()
  local from = self.CreateSelectedId
  local end_id = from and self.SelectedId or nil
  if from then
    local end_pos = end_id and graph:GetPos(end_id) or tr.HitPos + UP_10
    local points = self:AutoCreatePoints(graph:GetPos(from), end_pos)
    local previous = from
    -- The last generated point is replaced by the selected end node, if there is one.
    local count = end_id and #points - 1 or #points
    for i = 1, count do
      local id = graph:AddNode(points[i])
      graph:Link(id, previous, 'walk')
      self:LinkNew(id)
      previous = id
    end

    if end_id then
      graph:Link(end_id, previous, 'walk')
      self.CreateSelectedId = end_id
    elseif count == 0 then
      local id = graph:AddNode(tr.HitPos + UP_10)
      graph:Link(id, from, 'walk')
      self:LinkNew(id)
      self.CreateSelectedId = id
    else
      self.CreateSelectedId = previous
    end
  else
    local id = graph:AddNode(tr.HitPos + UP_10)
    self:LinkNew(id)
  end

  surface.PlaySound('common/wpn_select.wav')
end

function TOOL:RemoveNode(id)
  Graph():RemoveNode(id)
  if self.CreateSelectedId == id then self.CreateSelectedId = nil end
  if self.LinkerId == id then self.LinkerId = nil end
  surface.PlaySound('common/wpn_denyselect.wav')
end

function TOOL:RemoveLastNode()
  local graph = Graph()
  for id = graph.max_id, 1, -1 do
    if graph:Exists(id) then
      self:RemoveNode(id)
      return
    end
  end
end

function TOOL:ClearPoints()
  NavEditor.ClearGraph()
  self.CreateSelectedId = nil
  surface.PlaySound('common/wpn_denyselect.wav')
end

function TOOL:DrawHUD()
  surface.SetFont(hud_font)
  surface.SetTextColor(255, 255, 255)
  surface.SetTextPos(30, ScrH() / 2)
  local tool_type = self:GetCurrentType()
  if tool_type == 'creator' then
    surface.DrawText('#tool.bgn_point_editor.vis.creator')
  elseif tool_type == 'remover' then
    if self.LastNodeRemover then
      surface.DrawText(language.GetPhrase('tool.bgn_point_editor.vis.last_remover') .. ' - ' .. Graph():Count())
    else
      surface.DrawText('#tool.bgn_point_editor.vis.remover')
    end
  elseif tool_type == 'linker' then
    surface.DrawText(self.LinkFullParents and '#tool.bgn_point_editor.vis.linker_parents' or '#tool.bgn_point_editor.vis.linker')
  elseif tool_type == 'parents_cleaner' then
    surface.DrawText(self.LinkFullParents and '#tool.bgn_point_editor.vis.linker_cleaner_parents' or '#tool.bgn_point_editor.vis.linker_cleaner')
  end
end

local function Description(Panel, text)
  Panel:AddControl('Label', {
    ['Text'] = text
  })
end

function TOOL.BuildCPanel(Panel)
  Panel:AddControl('Button', {
    ['Label'] = '#tool.bgn_point_editor.pnl.load_points',
    ['Command'] = 'cl_citizens_load_route_from_client'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.load_points.desc')
  Panel:AddControl('Button', {
    ['Label'] = '#tool.bgn_point_editor.pnl.save_points',
    ['Command'] = 'cl_citizens_save_route'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.save_points.desc')
  Panel:AddControl('Button', {
    ['Label'] = '#tool.bgn_point_editor.pnl.generate_points',
    ['Command'] = 'bgn_nav_generate'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.generate_points.desc')
  Panel:AddControl('Button', {
    ['Label'] = '#tool.bgn_point_editor.pnl.generate_around',
    ['Command'] = 'bgn_nav_generate around'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.generate_around.desc')
  Panel:AddControl('Button', {
    ['Label'] = '#tool.bgn_point_editor.pnl.clear_points',
    ['Command'] = 'cl_bgn_clear_tool_points'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.clear_points.desc')
  Panel:AddControl('CheckBox', {
    ['Label'] = '#tool.bgn_point_editor.autoparent',
    ['Command'] = 'bgn_tool_point_editor_autoparent'
  })

  Description(Panel, '#tool.bgn_point_editor.autoparent.desc')
  Panel:AddControl('CheckBox', {
    ['Label'] = '#tool.bgn_point_editor.autoalignment',
    ['Command'] = 'bgn_tool_point_editor_autoalignment'
  })

  Description(Panel, '#tool.bgn_point_editor.autoalignment.desc')
  Panel:AddControl('Button', {
    ['Label'] = '#tool.bgn_point_editor.pnl.reconstruct_parents',
    ['Command'] = 'cl_tool_point_editor_reconstruct_parents'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.reconstruct_parents.desc')
  Panel:AddControl('Slider', {
    ['Label'] = '#tool.bgn_point_editor.pnl.z_limit',
    ['Command'] = 'bgn_point_z_limit',
    ['Type'] = 'Float',
    ['Min'] = '0',
    ['Max'] = '500'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.z_limit.desc')
  Panel:AddControl('Slider', {
    ['Label'] = '#tool.bgn_point_editor.pnl.bgn_tool_draw_distance',
    ['Command'] = 'bgn_tool_draw_distance',
    ['Type'] = 'Float',
    ['Min'] = '0',
    ['Max'] = '2000'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc')
  Panel:AddControl('CheckBox', {
    ['Label'] = '#tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents',
    ['Command'] = 'bgn_tool_point_editor_show_parents'
  })

  Description(Panel, '#tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents.desc')
end

do
  local en_lang = {
    ['tool.bgn_point_editor.name'] = 'Points Editor',
    ['tool.bgn_point_editor.desc'] = 'Tool for editing the points of movement of background NPCs.',
    ['tool.bgn_point_editor.0'] = 'Left click - Interaction. Right click - Change tool type. Reload - Switching submodes.',
    ['tool.bgn_point_editor.pnl.load_points'] = 'Load points',
    ['tool.bgn_point_editor.pnl.load_points.desc'] = 'Receives movement mesh from the server.',
    ['tool.bgn_point_editor.pnl.save_points'] = 'Save points',
    ['tool.bgn_point_editor.pnl.save_points.desc'] = 'Save the movement mesh on the server.',
    ['tool.bgn_point_editor.pnl.generate_points'] = 'Generate movement mesh',
    ['tool.bgn_point_editor.pnl.generate_points.desc'] = 'Generates movement points over the whole map, starting from the spawn points. Needed only on maps without NavMesh and AI nodes. Click again to stop.',
    ['tool.bgn_point_editor.pnl.generate_around'] = 'Generate around me',
    ['tool.bgn_point_editor.pnl.generate_around.desc'] = 'Generates movement points only around you (radius: bgn_dynamic_nodes_radius).',
    ['tool.bgn_point_editor.pnl.reconstruct_parents'] = 'Re-create points links',
    ['tool.bgn_point_editor.pnl.reconstruct_parents.desc'] = 'Automatically recreates all connections between points, taking into account the distance and obstacles.',
    ['tool.bgn_point_editor.autoparent'] = 'Auto parent',
    ['tool.bgn_point_editor.autoparent.desc'] = 'Enable automatic creation of links.',
    ['tool.bgn_point_editor.autoalignment'] = 'Auto-height',
    ['tool.bgn_point_editor.autoalignment.desc'] = 'Enable automatic height alignment.',
    ['tool.bgn_point_editor.pnl.z_limit'] = 'Height limit between points',
    ['tool.bgn_point_editor.pnl.z_limit.desc'] = 'Height limit between points. Used to correctly define child points.',
    ['tool.bgn_point_editor.vis.good_place'] = 'Good place',
    ['tool.bgn_point_editor.vis.lock_pos'] = 'Too far from other points',
    ['tool.bgn_point_editor.vis.creator'] = 'Creating points',
    ['tool.bgn_point_editor.vis.remover'] = 'Deleting a selected point',
    ['tool.bgn_point_editor.vis.last_remover'] = 'Delete last point',
    ['tool.bgn_point_editor.vis.linker'] = 'Linker node',
    ['tool.bgn_point_editor.vis.linker_parents'] = 'Linker parents node',
    ['tool.bgn_point_editor.vis.linker_cleaner'] = 'Cleaner node links',
    ['tool.bgn_point_editor.vis.linker_cleaner_parents'] = 'Cleaner parents node links',
    ['tool.bgn_point_editor.vis.selected'] = 'Selected',
    ['tool.bgn_point_editor.pnl.bgn_tool_draw_distance'] = 'Distance to draw points',
    ['tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'] = 'Sets the maximum distance to draw points in edit mode.',
    ['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents'] = 'Show global connections',
    ['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents.desc'] = 'Shows global (white) connections that are used by NPCs in special cases. For example - escape from the attacker.',
    ['tool.bgn_point_editor.pnl.clear_points'] = 'Clear all points (Local)',
    ['tool.bgn_point_editor.pnl.clear_points.desc'] = 'Removes all points from the tool in the client area. If the points are saved to a file and uploaded to the server, they will not disappear anywhere.',
  }

  local ru_lang = {
    ['tool.bgn_point_editor.name'] = 'Редактор точек',
    ['tool.bgn_point_editor.desc'] = 'Инструмент для редактирования точек перемещения фоновых НПС.',
    ['tool.bgn_point_editor.0'] = 'Левый клик - Взаимодействие. Правый клик - Сменить тип инструмента. Перезарядка - Переключение подрежимов.',
    ['tool.bgn_point_editor.pnl.load_points'] = 'Загрузить точки',
    ['tool.bgn_point_editor.pnl.load_points.desc'] = 'Получает сетку перемещения с сервера.',
    ['tool.bgn_point_editor.pnl.save_points'] = 'Сохранить точки',
    ['tool.bgn_point_editor.pnl.save_points.desc'] = 'Сохраняет сетку перемещения на сервере.',
    ['tool.bgn_point_editor.pnl.generate_points'] = 'Сгенерировать точки перемещения',
    ['tool.bgn_point_editor.pnl.generate_points.desc'] = 'Генерирует точки перемещения по всей карте, начиная с точек спавна. Нужно только на картах без NavMesh и AI-нод. Повторное нажатие останавливает.',
    ['tool.bgn_point_editor.pnl.generate_around'] = 'Сгенерировать вокруг меня',
    ['tool.bgn_point_editor.pnl.generate_around.desc'] = 'Генерирует точки перемещения только вокруг вас (радиус: bgn_dynamic_nodes_radius).',
    ['tool.bgn_point_editor.pnl.reconstruct_parents'] = 'Пересоздать связи точек',
    ['tool.bgn_point_editor.pnl.reconstruct_parents.desc'] = 'Автоматически пересоздаёт все связи между точками, с учётом дистанции и препятствий.',
    ['tool.bgn_point_editor.autoparent'] = 'Авто-связка',
    ['tool.bgn_point_editor.autoparent.desc'] = 'Включить автоматическое создание связей.',
    ['tool.bgn_point_editor.autoalignment'] = 'Авто-высота',
    ['tool.bgn_point_editor.autoalignment.desc'] = 'Включить автоматическое выравнивание по высоте.',
    ['tool.bgn_point_editor.pnl.z_limit'] = 'Ограничение высоты между точками',
    ['tool.bgn_point_editor.pnl.z_limit.desc'] = 'Ограничение высоты между точками. Используется для правильного определения дочерних точек.',
    ['tool.bgn_point_editor.vis.good_place'] = 'Хорошая позиция',
    ['tool.bgn_point_editor.vis.lock_pos'] = 'Слишком далеко от других точек',
    ['tool.bgn_point_editor.vis.creator'] = 'Создание точек',
    ['tool.bgn_point_editor.vis.remover'] = 'Удаление выбранной точки',
    ['tool.bgn_point_editor.vis.last_remover'] = 'Удалить последнюю точку',
    ['tool.bgn_point_editor.vis.linker'] = 'Соединитель',
    ['tool.bgn_point_editor.vis.linker_parents'] = 'Соединитель родительских нод',
    ['tool.bgn_point_editor.vis.linker_cleaner'] = 'Очиститель связей',
    ['tool.bgn_point_editor.vis.linker_cleaner_parents'] = 'Очиститель родительских связей',
    ['tool.bgn_point_editor.vis.selected'] = 'Выбрано',
    ['tool.bgn_point_editor.pnl.bgn_tool_draw_distance'] = 'Дистанция прорисовки точек',
    ['tool.bgn_point_editor.pnl.bgn_tool_draw_distance.desc'] = 'Устанавливает максимальное расстояние отрисовки точек в режиме редактирования.',
    ['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents'] = 'Показать глобальные связи',
    ['tool.bgn_point_editor.pnl.bgn_tool_point_editor_show_parents.desc'] = 'Показывает глобальные (белые) соединения, которые используются НПС в особых случаях. Например - побег от нападавшего.',
    ['tool.bgn_point_editor.pnl.clear_points'] = 'Очистить все точки (Локально)',
    ['tool.bgn_point_editor.pnl.clear_points.desc'] = 'Удаляет все точки из инструмента в области клиента. Если точки сохранены в файл и загружена на сервер, они никуда не исчезнут.',
  }

  local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
  for k, v in pairs(lang) do
    language.Add(k, v)
  end
end

-- ---------------------------------------------------------------------------
-- Rendering
-- ---------------------------------------------------------------------------
local function GetCameraAngle()
  local cam_angle = LocalPlayer():EyeAngles()
  cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
  cam_angle:RotateAroundAxis(cam_angle:Right(), 90)
  return cam_angle
end

local function DrawLabel(pos, text, y)
  cam.Start3D2D(pos + UP_20, GetCameraAngle(), 0.9)
  draw.SimpleTextOutlined(text, text_font, 0, y or 0, color_text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_outline)
  cam.End3D2D()
end

hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PointEditorRender', function()
  local tool = bgNPC.Util.GetActivePlayerTool('bgn_point_editor', LocalPlayer())
  if not tool then return end
  local graph = Graph()
  local show_plain = GetConVar('bgn_tool_point_editor_show_parents'):GetBool()
  local drawn = {}
  render.SetColorMaterial()
  -- Points and their links
  for _, value in ipairs(tool.RangePoints) do
    local id = value.id
    local pos = graph:GetPos(id)
    if pos then
      drawn[id] = true
      for other in pairs(graph.links[id]) do
        if not drawn[other] then
          local other_pos = graph:GetPos(other)
          if graph:IsLinked(id, other, 'walk') then
            render.DrawLine(pos, other_pos, value.behind_wall and clr_link_alpha or clr_link)
          elseif show_plain then
            render.DrawLine(pos, other_pos, value.behind_wall and clr_parent_alpha or clr_parent)
          end
        end
      end

      local has_walk = graph:HasLinks(id, 'walk')
      local color = (id == tool.SelectedId and tool.CreateSelectedId) and clr_green or has_walk and clr_point or clr_point_notlinks
      render.DrawSphere(pos, 10, 5, 5, color)
      if id == tool.SelectedId then
        local walk_count = #graph:GetNeighbours(id, 'walk')
        if walk_count ~= 0 then DrawLabel(pos, 'Walk links - ' .. walk_count) end
        DrawLabel(pos, '#tool.bgn_point_editor.vis.selected', 25)
      end
    end
  end

  local tool_type = tool:GetCurrentType()
  local tr = tool:GetTraceInfo()
  if not tr.Hit then return end
  -- Linker preview
  if tool.LinkerId and graph:Exists(tool.LinkerId) then
    local linker_pos = graph:GetPos(tool.LinkerId)
    render.DrawSphere(linker_pos, 10, 5, 5, clr_green)
    if tool.SelectedId and linker_pos:DistToSqr(tr.HitPos) <= LINK_DISTANCE_SQR then
      local pos = graph:GetPos(tool.SelectedId)
      render.DrawSphere(pos, 10, 5, 5, clr_good)
      render.DrawLine(linker_pos, pos, clr_good)
    else
      render.DrawLine(linker_pos, tr.HitPos, clr_bad)
    end
  end

  if tool_type ~= 'creator' then return end
  -- Creator preview: a chain from the selected node
  if tool.CreateSelectedId and graph:Exists(tool.CreateSelectedId) then
    local start_pos = graph:GetPos(tool.CreateSelectedId)
    local end_pos = tool.SelectedId and graph:GetPos(tool.SelectedId) or tr.HitPos
    render.DrawSphere(start_pos, 10, 5, 5, clr_good)
    local previous = start_pos
    for _, pos in ipairs(tool:AutoCreatePoints(start_pos, end_pos)) do
      render.DrawLine(previous, pos, clr_good)
      render.DrawSphere(pos, 10, 5, 5, clr_good)
      previous = pos
    end

    render.DrawLine(previous, end_pos, clr_good)
    return
  end

  -- Creator preview: a single new point
  if tool.SelectedId then return end
  local trace_pos = tr.HitPos
  local future = {}
  graph:ForEachInRadius(trace_pos, NavEditor.LINK_DISTANCE, function(_, pos) if NavEditor.CanAutoLink(trace_pos, pos) then future[#future + 1] = pos end end)
  local too_far = graph:Count() ~= 0 and #future == 0
  render.DrawSphere(trace_pos, 10, 5, 5, too_far and clr or clr_green)
  DrawLabel(trace_pos, too_far and '#tool.bgn_point_editor.vis.lock_pos' or '#tool.bgn_point_editor.vis.good_place')
  for _, pos in ipairs(future) do
    render.DrawLine(trace_pos, pos, clr_future)
  end
end)
