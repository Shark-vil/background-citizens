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

    function TOOL:DrawHUD()
        if self.Actor == nil or not IsValid(self.Target) then return end

        local ypos = ScrH() / 3
        local add = 25

        surface.SetFont("Trebuchet18")
        surface.SetTextColor(255, 255, 255)
        surface.SetTextPos(30, ypos) 
        surface.DrawText('State - ' .. self.Actor:GetState())

        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('Is animated - ' .. tostring(self.Actor.is_animated))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('Animation time - ' .. tostring(self.Actor.anim_time_normal))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('Animation loop time - ' .. tostring(self.Actor.loop_time_normal))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('Animation is loop - ' .. tostring(self.Actor.anim_is_loop))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('Animation name - ' .. tostring(self.Actor.anim_name))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('Target count - ' .. tostring(#self.Actor.targets))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('NPC schedule - ' .. tostring(self.Actor.npc_schedule))
        ypos = ypos + add
        surface.SetTextPos(30, ypos)
        surface.DrawText('NPC state - ' .. tostring(self.Actor.npc_state))
    end
    
    function TOOL:UpdateControlPanel()
        local Panel = controlpanel.Get("bgn_debugger")
        if not Panel then MsgN("Couldn't find bgn_debugger panel!") return end
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