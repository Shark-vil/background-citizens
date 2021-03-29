TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_seat_tool.name"
TOOL.Trace = nil
TOOL.Distance = 10000
TOOL.VectorOffset = Vector(0, 0, 0)
TOOL.AngleOffset = Angle(0, 0, 0)
TOOL.SeatPoints = {}
TOOL.SelectedPointId = -1
TOOL.LastIndex = -1
TOOL.SetStartPos = true

function TOOL:GetTraceInfo()
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

function TOOL:LeftClick()
   if CLIENT then return end
   snet.Invoke('bgn_tool_bgn_seat_left_click', self:GetOwner())
end

function TOOL:RightClick()
   if CLIENT then return end
   snet.Invoke('bgn_tool_bgn_seat_right_click', self:GetOwner())
end

function TOOL:Reload()
   if CLIENT then return end
   snet.Invoke('bgn_tool_bgn_seat_reload_click', self:GetOwner())
end

if CLIENT then
   function TOOL:IsLookingVector(vec)
		local diff = vec - self.Owner:GetShootPos()
		return self.Owner:GetAimVector():Dot(diff) / diff:Length() >= 0.99
	end

   function TOOL:Think()
      do
         local x = GetConVar('bgn_tool_seat_offset_pos_x'):GetInt()
         local y = GetConVar('bgn_tool_seat_offset_pos_y'):GetInt()
         local z = GetConVar('bgn_tool_seat_offset_pos_z'):GetInt()
         self.VectorOffset = Vector(x, y, z)
      end

      do
         local x = GetConVar('bgn_tool_seat_offset_angle_x'):GetInt()
         local y = GetConVar('bgn_tool_seat_offset_angle_y'):GetInt()
         local z = GetConVar('bgn_tool_seat_offset_angle_z'):GetInt()
         self.AngleOffset = Angle(x, y, z)
      end

      local NewSelectedPointId = -1

      for index, t in ipairs(self.SeatPoints) do
         if NewSelectedPointId == -1 and t.data.position and self:IsLookingVector(t.data.position) then
            NewSelectedPointId = index
            break
         end
      end

      self.SelectedPointId = NewSelectedPointId

      self:UpdateControlPanel()
   end

   snet.RegisterCallback('bgn_tool_bgn_seat_reload_click', function()
      local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end

		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
      if not tool then return end

      for _, t in ipairs(tool.SeatPoints) do
         if t.m_citizen then
            t.m_citizen:Remove()
         end
      end

      table.Empty(tool.SeatPoints)

      tool.SelectedPointId = -1
      tool.LastIndex = -1
      tool.SetStartPos = true
   end)

   snet.RegisterCallback('bgn_tool_bgn_seat_right_click', function()
      local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end

		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
      if not tool then return end

      if tool.SelectedPointId == -1 then return end

      local point = tool.SeatPoints[tool.SelectedPointId]
      if not point then return end

      point.m_citizen:Remove()
      table.remove(tool.SeatPoints, tool.SelectedPointId)

      tool.SelectedPointId = -1
   end)

   snet.RegisterCallback('bgn_tool_bgn_seat_left_click', function(ply)
      local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then return end

		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
      if not tool then return end

      local tr = tool:GetTraceInfo()
      if not tr.Hit then return end

      if tool.SetStartPos then
         local m_citizen = ClientsideModel('models/Humans/Group01/male_02.mdl')
         m_citizen:SetSequence('Sit_Chair')
         m_citizen:Spawn()

         tool.LastIndex = table.insert(tool.SeatPoints, {
            data = {
               start_pos =  tr.HitPos,
            },
            m_citizen = m_citizen,
         })
      elseif tool.LastIndex ~= -1 then
         tool.SeatPoints[tool.LastIndex].data.position = tr.HitPos
         tool.SeatPoints[tool.LastIndex].data.offset = tool.VectorOffset
         tool.SeatPoints[tool.LastIndex].data.angle = tool.AngleOffset
         tool.LastIndex = -1
      end

      tool.SetStartPos = not tool.SetStartPos
   end)

   function TOOL:UpdateControlPanel()
		if self.PanelIsInit then return end

		local Panel = controlpanel.Get( "bgn_seat_tool" )
		if not Panel then bgNPC:Log("Couldn't find bgn_seat_tool panel!", 'Tool') return end
	
		self.PanelIsInit = true
	
		Panel:ClearControls()

      Panel:AddControl("Button", {
			["Label"] = "Save",
			["Command"] = "bgn_tool_seat_save",
		})
	
      Panel:AddControl("Button", {
			["Label"] = "Load",
			["Command"] = "bgn_tool_seat_load",
		})

		Panel:AddControl("Slider", {
			["Label"] = "Pos X",
			["Command"] = "bgn_tool_seat_offset_pos_x",
			["Type"] = "Integer",
			["Min"] = "-180",
			["Max"] = "180"
		})

      Panel:AddControl("Slider", {
			["Label"] = "Pos Y",
			["Command"] = "bgn_tool_seat_offset_pos_y",
			["Type"] = "Integer",
			["Min"] = "-180",
			["Max"] = "180"
		})

      Panel:AddControl("Slider", {
			["Label"] = "Pos Z",
			["Command"] = "bgn_tool_seat_offset_pos_z",
			["Type"] = "Integer",
			["Min"] = "-180",
			["Max"] = "180"
		})

      Panel:AddControl("Slider", {
			["Label"] = "Ang X",
			["Command"] = "bgn_tool_seat_offset_angle_x",
			["Type"] = "Integer",
			["Min"] = "-180",
			["Max"] = "180"
		})

      Panel:AddControl("Slider", {
			["Label"] = "Ang Y",
			["Command"] = "bgn_tool_seat_offset_angle_y",
			["Type"] = "Integer",
			["Min"] = "-180",
			["Max"] = "180"
		})

      Panel:AddControl("Slider", {
			["Label"] = "Ang Z",
			["Command"] = "bgn_tool_seat_offset_angle_Z",
			["Type"] = "Integer",
			["Min"] = "-180",
			["Max"] = "180"
		})
	end

   local m_citizen
   local clr = Color(255, 225, 0, 200)
	local clr_green = Color(72, 232, 9, 200)
   
   hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_SeatEditor', function()
		local wep = LocalPlayer():GetActiveWeapon()
		if not IsValid(wep) or wep:GetClass() ~= 'gmod_tool' then
         if m_citizen then m_citizen:Remove() m_citizen = nil end
         return
      end

		local tool = bgNPC:GetActivePlayerTool('bgn_seat_tool')
      if not tool then
         if m_citizen then m_citizen:Remove() m_citizen = nil end
         return
      end

      local tr = tool:GetTraceInfo()
      if not tr.Hit then return end

      if tool.SelectedPointId ~= -1 then
         if m_citizen then m_citizen:Remove() m_citizen = nil end
      else
         if tool.SetStartPos then
            render.DrawSphere(tr.HitPos, 10, 20, 20, clr_green)
            if m_citizen then m_citizen:Remove() m_citizen = nil end
         else
            if not m_citizen then
               m_citizen = ClientsideModel('models/Humans/Group01/male_02.mdl')
               m_citizen:SetSequence('Sit_Chair')
               m_citizen:Spawn()
            end

            m_citizen:SetPos(tr.HitPos + tool.VectorOffset)
            m_citizen:SetAngles(tool.AngleOffset)
         end
      end

      render.SetColorMaterial()

      for index, t in ipairs(tool.SeatPoints) do
         local data = t.data
         if not data.position and data.start_pos then
            render.DrawLine(data.start_pos, tr.HitPos, clr)
         end
      end

      for index, t in ipairs(tool.SeatPoints) do
         local data = t.data
         if data.start_pos and data.position then
            local model = t.m_citizen

            if tool.SelectedPointId == index then
               model:SetColor(Color(100, 0, 0))
            else
               model:SetColor(Color(255, 255, 255))
            end

            model:SetPos(data.position + data.offset)
            model:SetAngles(data.angle)

            render.DrawSphere(data.start_pos, 10, 20, 20, clr_green)
            render.DrawLine(data.start_pos, data.position, clr)
         end
      end
   end)

   local en_lang = {
		['tool.bgn_seat_tool.name'] = 'Seat position',
		['tool.bgn_seat_tool.desc'] = '',
		['tool.bgn_seat_tool.0'] = '',
	}

	local ru_lang = {
		['tool.bgn_seat_tool.name'] = 'Позиция сиденья',
		['tool.bgn_seat_tool.desc'] = '',
		['tool.bgn_seat_tool.0'] = '',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end
end