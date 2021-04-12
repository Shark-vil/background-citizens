TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_actor_mover.name"
TOOL.Trace = nil
TOOL.Distance = 10000
TOOL.Actor = nil
TOOL.Target = NULL
TOOL.Path = {}
TOOL.UpdatePathDelay = 0

if SERVER then
	hook.Add('BGN_PreSetNPCState', 'BGN_Debugger_ActorMover', function(actor)
		if actor.debugger then return true end
	end)

	function TOOL:Think()
		if self.Actor == nil or not IsValid(self.Target) then return end
		if self.UpdatePathDelay < CurTime() then
			snet.ClientRPC(self, 'UpdatePath', self.Actor.walkPath)
			self.UpdatePathDelay = CurTime() + 1
		end
	end

	function TOOL:LeftClick()
		if CLIENT then return end

		local ply = self:GetOwner()
		if not ply:IsAdmin() or not ply:IsSuperAdmin() then return end

		local tr = util.TraceLine({
			start = ply:GetShootPos(),
			endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
			filter = function(ent)
				if ent ~= ply and (ent:IsNPC() or ent:IsVehicle()) then
					return true
				end
			end
		})

		if not tr.Hit then return end
		local actor

		local ent = tr.Entity
		if ent:IsVehicle() and ent.bgn_driver then
			actor = ent.bgn_driver
		else
			actor = bgNPC:GetActor(ent)
		end

		if not actor then
			bgNPC:Log('Failed to convert ' .. tostring(ent) .. ' to actor', 'Debugger')
			return
		end

		snet.IsValidForClient(ply, function(ply, success)
			bgNPC:Log('Actor validator result: ' .. tostring(ply) .. ' - ' ..  tostring(success), 'Debugger')
			if not success then return end

			if self.Actor then
				self.Actor.debugger = false
				self.Actor.eternal = false
				self.Actor:RandomState()
			end

			actor:SetState('none')
			actor.debugger = true
			actor.eternal = true
			
			self.Actor = actor
			self.Target = actor:GetNPC()

			snet.ClientRPC(self, 'SetActor', actor.uid)
		end, 'actor', actor.uid)
	end

	function TOOL:RightClick()
		if SERVER then
			local ply = self:GetOwner()
			if not ply:IsAdmin() or not ply:IsSuperAdmin() then return end
			if not IsValid(self.Target) or self.Actor == nil then return end

			local tr = util.TraceLine({
				start = ply:GetShootPos(),
				endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
				filter = function(ent)
					if ent ~= ply then
						return true
					end
				end
			})
			
			if not tr.Hit then return end
			self.Actor:ClearSchedule()

			local pos = tr.HitPos
			
			if self.Target:GetPos():Distance(pos) <= 500 then
				self.Actor:WalkToPos(pos)
			else
				self.Actor:WalkToPos(pos, 'run')
			end

			snet.ClientRPC(self, 'UpdatePath', self.Actor.walkPath)
		end
	end

	function TOOL:Reload()
		if CLIENT then return end

		if self.Actor ~= nil then
			self.Actor.debugger = false
			self.Actor.eternal = false
			self.Actor:RandomState()
		end

		self.Actor = nil
		self.Target = NULL

		snet.ClientRPC(self, 'ResetActor')
	end
else
   function TOOL:ResetActor()
      self.Actor = nil
      self.Target = NULL
		self.Path = {}
   end

	function TOOL:SetActor(uid)
		local actor = bgNPC:GetActorByUid(uid)
		if actor == nil then
			bgNPC:Log('Failed to convert ' .. uid .. ' to actor', 'Debugger')
			surface.PlaySound('common/wpn_denyselect.wav')
			return
		end

		self.Actor = actor
		self.Target = actor:GetNPC()
		surface.PlaySound('common/wpn_select.wav')
	end

	function TOOL:UpdatePath(path)
		self.Path = path
	end

   local halo_color = Color(196, 0, 255)
	hook.Add("PreDrawHalos", "BGN_TOOL_ActorMover", function()
		if not SLibraryIsLoaded then return end

      local tool = LocalPlayer():slibGetActiveTool('bgn_actor_mover')
      if not tool or not tool.Actor or not IsValid(tool.Target) then return end

      halo.Add({ tool.Target }, halo_color, 3, 3, 2)
	end)

	local clr_green = Color(72, 232, 9, 200)
   local clr_58 = Color(58, 23, 255, 200)
   local color_white = Color(255, 255, 255)
	local color_black = Color(0, 0, 0)
   local vec_20 = Vector(0, 0, 20)

	hook.Add('PostDrawOpaqueRenderables', 'BGN_TOOL_ActorMovement', function()
		if not SLibraryIsLoaded then return end

      local tool = LocalPlayer():slibGetActiveTool('bgn_actor_mover')
      if not tool or #tool.Path == 0 then return end

      render.SetColorMaterial()

      for i = #tool.Path, 1, -1 do
         local pos = tool.Path[i]

         if i ~= 1 then
            render.DrawLine(pos, tool.Path[i - 1], clr_58)
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
		['tool.bgn_actor_mover.name'] = 'Actor mover',
		['tool.bgn_actor_mover.desc'] = 'Forces the selected actor to go to the specified point.',
		['tool.bgn_actor_mover.0'] = 'Left click - select actor. Right click - set movement point. Reload - reset selected actor.',
	}

	local ru_lang = {
		['tool.bgn_actor_mover.name'] = 'Двигатель актёров',
		['tool.bgn_actor_mover.desc'] = 'Заставляет выделенного актёра идти к указанной точке.',
		['tool.bgn_actor_mover.0'] = 'Левый клик - выделить актёра. Правый клик - задать точку движения. Перезарядка - отменить выделение актёра.',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end
end