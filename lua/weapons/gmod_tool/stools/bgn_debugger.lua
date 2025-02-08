local surface = surface
local LocalPlayer = LocalPlayer
--

TOOL.Category = 'Background NPCs'
TOOL.Name = '#tool.bgn_debugger.name'
TOOL.PanelIsInit = false
TOOL.Trace = nil
TOOL.Lock = false
TOOL.Distance = 10000
TOOL.Actor = nil
TOOL.Target = NULL

if SERVER then
	function TOOL:LeftClick()
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

			local actor_data = snet.GetNormalizeDataTable(actor)
			if actor_data then MsgN('SERVER:', '\nACTOR: ' .. actor.type .. '\n') PrintTable(actor_data) end

			snet.ClientRPC(self, 'SetActor', actor.uid)
		end, 'actor', actor.uid)
	end

	function TOOL:RightClick()
		snet.ClientRPC(self, 'ResetActor')
	end
else
	function TOOL:SetActor(uid)
		local actor = bgNPC:GetActorByUid(uid)
		if actor == nil then
			bgNPC:Log('Failed to convert ' .. uid .. ' to actor', 'Debugger')
			surface.PlaySound('common/wpn_denyselect.wav')
			return
		end

		local actor_data = snet.GetNormalizeDataTable(actor)
		if actor_data then MsgN('CLIENT:', '\nACTOR: ' .. actor.type .. '\n') PrintTable(actor_data) end

		self.Actor = actor
		self.Target = actor:GetNPC()
		surface.PlaySound('common/wpn_select.wav')
	end

	function TOOL:ResetActor()
		self.Actor = nil
		self.Target = NULL
		surface.PlaySound('buttons/blip1.wav')
	end

	hook.Add('HUDPaint', 'BGN_TOOL_DrawDebbugerText', function()
		if not SLibraryIsLoaded then return end

		local tool = LocalPlayer():slibGetActiveTool('bgn_debugger')
		if not tool or not tool.Actor or not IsValid(tool.Target) then return end

		local ypos = ScrH() / 3
		local add = 25

		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(25, ypos - 10, 240, 260)

		surface.SetFont('Trebuchet18')
		surface.SetTextColor(255, 255, 255)

		surface.SetTextPos(30, ypos)
		surface.DrawText('Uid - ' .. tostring(tool.Actor.uid))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('State - ' .. tool.Actor:GetState())

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('Is animated - ' .. tostring(tool.Actor.is_animated))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('Animation time - ' .. tostring(tool.Actor.anim_time_normal))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('Animation loop time - ' .. tostring(tool.Actor.loop_time_normal))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('Animation is loop - ' .. tostring(tool.Actor.anim_is_loop))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('Animation name - ' .. tostring(tool.Actor.anim_name))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('Target count - ' .. tostring(#tool.Actor.targets))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('NPC schedule - ' .. tostring(tool.Actor.npc_schedule))

		ypos = ypos + add
		surface.SetTextPos(30, ypos)
		surface.DrawText('NPC state - ' .. tostring(tool.Actor.npc_state))
	end)

	function TOOL:UpdateControlPanel()
		local Panel = controlpanel.Get('bgn_debugger')
		if not Panel then bgNPC:Log('Couldn\'t find bgn_debugger panel!', 'Tool') return end
		if self.PanelIsInit then return end

		self.PanelIsInit = true

		Panel:ClearControls()
	end

	local en_lang = {
		['tool.bgn_debugger.name'] = 'Actor debugger',
		['tool.bgn_debugger.desc'] = 'A tool for debugging the work of actors.',
		['tool.bgn_debugger.0'] = 'Left click - select actor. Right click - reset selected actor',
	}

	local ru_lang = {
		['tool.bgn_debugger.name'] = 'Дебаггер актёров',
		['tool.bgn_debugger.desc'] = 'Инструмент для отладки работы актёров.',
		['tool.bgn_debugger.0'] = 'Левый клик - выделить актёра. Правый клик - отменить выделение актёра.',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end
end