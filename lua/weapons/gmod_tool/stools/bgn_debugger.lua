TOOL.Category = "Background NPCs"
TOOL.Name = "#tool.bgn_debugger.name"

TOOL.PanelIsInit = false
TOOL.IsBGNDebuggerEditor = true
TOOL.Trace = nil
TOOL.Lock = false
TOOL.Distance = 10000
TOOL.Actor = nil
TOOL.Target = NULL

function TOOL:LeftClick()
	if SERVER then
		self:GetOwner():ConCommand('cl_bgn_debuger_tool_left_click')
		return
	end
end

function TOOL:RightClick()
	if SERVER then
		self:GetOwner():ConCommand('cl_bgn_debuger_tool_right_click')
		return
	end
end

if CLIENT then
	concommand.Add('cl_bgn_debuger_tool_left_click', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNDebuggerEditor then return end
		
		local tr = util.TraceLine( {
			start = LocalPlayer():GetShootPos(),
			endpos = LocalPlayer():GetShootPos() + LocalPlayer():GetAimVector() * tool.Distance,
			filter = function(ent)
				if ent ~= LocalPlayer() then
					return true
				end
			end
		} )

		if tr.Hit and IsValid(tr.Entity) then
			local actor = bgNPC:GetActor(tr.Entity)
			if actor ~= nil then
				tool.Actor = actor
				tool.Target = actor:GetNPC()
				surface.PlaySound('common/wpn_select.wav')
			end
		end
	end)

	concommand.Add('cl_bgn_debuger_tool_right_click', function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNDebuggerEditor then return end

		tool.Actor = nil
		tool.Target = NULL
		surface.PlaySound('buttons/blip1.wav')
	end)

	hook.Add("HUDPaint", "BGN_TOOL_DrawDebbugerText", function()
		local tool = LocalPlayer():GetTool()
		if tool == nil or not tool.IsBGNDebuggerEditor then return end

		if tool.Actor == nil or not IsValid(tool.Target) then return end

		local ypos = ScrH() / 3
		local add = 25

		surface.SetDrawColor(0, 0, 0, 150)
		surface.DrawRect(25, ypos - 10, 240, 250)

		surface.SetFont("Trebuchet18")
		surface.SetTextColor(255, 255, 255)
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
		local Panel = controlpanel.Get("bgn_debugger")
		if not Panel then bgNPC:Log("Couldn't find bgn_debugger panel!", 'Tool') return end
		if self.PanelIsInit then return end
	
		self.PanelIsInit = true
	
		Panel:ClearControls()
	end
	
	local en_lang = {
		['tool.bgn_debugger.name'] = 'Actor debugger',
		['tool.bgn_debugger.desc'] = 'A tool for debugging the work of actors.',
		['tool.bgn_debugger.0'] = '',
	}

	local ru_lang = {
		['tool.bgn_debugger.name'] = 'Дебаггер актёров',
		['tool.bgn_debugger.desc'] = 'Инструмент для отладки работы актёров.',
		['tool.bgn_debugger.0'] = '',
	}

	local lang = GetConVar('cl_language'):GetString() == 'russian' and ru_lang or en_lang
	for k, v in pairs(lang) do
		language.Add(k, v)
	end
end