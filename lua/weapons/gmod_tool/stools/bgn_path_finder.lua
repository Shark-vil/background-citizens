TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_path_finder.name"
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
      snet.ClientRPC(self, 'LeftClick')
   end

   function TOOL:RightClick()
      if not game.SinglePlayer() then return end
      snet.ClientRPC(self, 'RightClick')
   end

   function TOOL:Reload()
      if not game.SinglePlayer() then return end
      snet.ClientRPC(self, 'Reload')
   end
else
   function TOOL:GetTrace()
      local ply = self:GetOwner()
      local tr = util.TraceLine({
         start = ply:GetShootPos(),
         endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
         filter = function(ent)
            if ent ~= ply then 
               return true
            end
         end
      })
      return tr
   end

   function TOOL:ClearPoints()
      self.StartPos = nil
      self.EndPos = nil
      table.Empty(self.Path)
   end

   function TOOL:Think()
      self:UpdateControlPanel()
   end

   function TOOL:UpdateControlPanel()
      if self.PanelIsInit then return end

      local Panel = controlpanel.Get( "bgn_path_finder" )
      if not Panel then bgNPC:Log("Couldn't find bgn_path_finder panel!", 'Tool') return end

      self.PanelIsInit = true

      Panel:ClearControls()

      Panel:AddControl("Button", {
         ["Label"] = "#tool.bgn_path_finder.pnl.load_points",
         ["Command"] = "cl_citizens_load_route_from_client",
      })
   end

   function TOOL:LeftClick()
      local tr = self:GetTrace()
      if not tr.Hit then return end

      self.StartPos = tr.HitPos

      surface.PlaySound('buttons/blip1.wav')
   end

   function TOOL:RightClick()
      if self.StartPos == nil then return end

      local tr = self:GetTrace()
      if not tr.Hit then return end

      self.EndPos = tr.HitPos

      local foundPath = bgNPC:FindWalkPath(self.StartPos, self.EndPos)
      if foundPath and istable(foundPath) then
         self.Path = foundPath
      end

      surface.PlaySound('buttons/blip1.wav')
   end

   function TOOL:Reload()
      self:ClearPoints()
      surface.PlaySound('common/wpn_denyselect.wav')
   end
   
   local clr_green = Color(72, 232, 9, 200)
   local clr_232_59 = Color(232, 59, 255, 255)
   local color_white = Color(255, 255, 255)
	local color_black = Color(0, 0, 0)
   local vec_20 = Vector(0, 0, 20)

   hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_PathFinder', function()
      if not SLibraryIsLoaded then return end

      local tool = LocalPlayer():slibGetActiveTool('bgn_path_finder')
      if not tool then return end

      render.SetColorMaterial()

      for i = #tool.Path, 1, -1 do
         local pos = tool.Path[i]

         if i ~= 1 then
            render.DrawLine(pos, tool.Path[i - 1], clr_232_59)
         end

         render.DrawSphere(pos, 10, 30, 30, clr_green)

         local cam_angle = LocalPlayer():EyeAngles()
         cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
         cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

         cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
            draw.SimpleTextOutlined(tostring(i), 
               "TargetID", 0, 0, color_white, 
               TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
         cam.End3D2D()
      end
   end)

   local en_lang = {
      ['tool.bgn_path_finder.name'] = 'Path finder',
      ['tool.bgn_path_finder.desc'] = '',
      ['tool.bgn_path_finder.0'] = '',
      ['tool.bgn_path_finder.pnl.load_points'] = 'Load points',
   }

   local ru_lang = {
      ['tool.bgn_path_finder.name'] = 'Поиск пути',
      ['tool.bgn_path_finder.desc'] = '',
      ['tool.bgn_path_finder.0'] = '',
      ['tool.bgn_path_finder.pnl.load_points'] = 'Загрузить точки',
   }

   local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
   for k, v in pairs(lang) do
      language.Add(k, v)
   end
end