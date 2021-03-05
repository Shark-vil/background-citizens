if SERVER then
	util.AddNetworkString('bgn_network_tool_actor_mover_left_click')
   util.AddNetworkString('bgn_network_tool_actor_mover_reset')
end

TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_actor_mover.name"

TOOL.IsBGNActorMoverEditor = true
TOOL.Trace = nil
TOOL.Distance = 10000
TOOL.Actor = nil
TOOL.Target = NULL

hook.Add('BGN_PreSetNPCState', 'BGN_Debugger_ActorMover', function(actor)
   if actor.debugger then return true end
end)

function TOOL:LeftClick()
	if CLIENT then return end

	local ply = self:GetOwner()
	if not ply:IsAdmin() or not ply:IsSuperAdmin() then return end

	local tr = util.TraceLine({
		start = ply:GetShootPos(),
		endpos = ply:GetShootPos() + ply:GetAimVector() * self.Distance,
		filter = function(ent)
			if ent ~= ply and ent:IsNPC() then
				return true
			end
		end
	})

	if not tr.Hit then return end

	local ent = tr.Entity
	local actor = bgNPC:GetActor(ent)
	if actor == nil then
		bgNPC:Log('Failed to convert ' .. tostring(ent) .. ' to actor', 'Debugger')
		return
	end

	snet.IsValidForClient(ply, function(ply, success)
		bgNPC:Log('Actor validator result: ' .. tostring(ply) .. ' - ' ..  tostring(success), 'Debugger')

		if success then
         actor:SetState('none')
         actor.debugger = true

         self.Actor = actor
		   self.Target = actor:GetNPC()

			net.Start('bgn_network_tool_actor_mover_left_click')
			net.WriteEntity(ent)
			net.Send(ply)
		end
	end, 'actor', 'bgn_debugger_tool', nil, ent)
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
      
      self.Actor:WalkToPos(tr.HitPos)
	end
end

function TOOL:Reload()
   if CLIENT then return end

   if self.Actor ~= nil then
      self.Actor.debugger = false
      self.Actor:RandomState()
   end

   self.Actor = nil
   self.Target = NULL

   net.Start('bgn_network_tool_actor_mover_reset')
   net.Send(self:GetOwner())
end

if CLIENT then
   net.Receive('bgn_network_tool_actor_mover_reset', function()
      local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNActorMoverEditor then return end

      tool.Actor = nil
      tool.Target = NULL
   end)

	net.Receive('bgn_network_tool_actor_mover_left_click', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNActorMoverEditor then return end
		
		local ent = net.ReadEntity()
		if not IsValid(ent) or not ent:IsNPC() then
			bgNPC:Log('Entity is not NPC or is equal to NULL', 'Debugger')
			surface.PlaySound('common/wpn_denyselect.wav')
			return
		end

		local actor = bgNPC:GetActor(ent)
		if actor == nil then
			bgNPC:Log('Failed to convert ' .. tostring(ent) .. ' to actor', 'Debugger')
			surface.PlaySound('common/wpn_denyselect.wav')
			return
		end

		tool.Actor = actor
		tool.Target = actor:GetNPC()
		surface.PlaySound('common/wpn_select.wav')
	end)

   local halo_color = Color(196, 0, 255)
	hook.Add("PreDrawHalos", "BGN_TOOL_ActorMover", function()
		local tool = LocalPlayer():GetTool()

		if tool == nil or not tool.IsBGNActorMoverEditor then return end
		if tool.Actor == nil or not IsValid(tool.Target) then return end

      halo.Add({ tool.Target }, halo_color, 3, 3, 2)
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