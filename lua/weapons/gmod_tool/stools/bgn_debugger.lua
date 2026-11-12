TOOL.Category = 'Background NPCs Debug'
TOOL.Name = '#tool.bgn_debugger.name'
TOOL.Information = {{name='left'},{name='right'},{name='reload'}}
if SERVER then
  function TOOL:LeftClick(tr)
    local p=self:GetOwner()
    if not IsValid(p) or not (p:IsAdmin() or p:IsSuperAdmin()) then return false end
    local a=bgNPC.Actors.Get(tr.Entity)
    if not a then
      for _,provider in ipairs(bgNPC.DVCars or {}) do if provider:GetVehicle()==tr.Entity then a=provider:GetDriver() break end end
    end
    if not a or not a:IsAlive() then return false end
    bgNPC.Net.ToolRPC(self,'SelectActor',a.uid)
    return true
  end
  function TOOL:RightClick() bgNPC.Net.ToolRPC(self,'ClearActor') return true end
  function TOOL:Reload() bgNPC.Net.ToolRPC(self,'PinActor') return true end
else
  function TOOL:SelectActor(uid)
    if bgNPC.DebugInspector.pinned then return end
    RunConsoleCommand('bgn_debug_select',tostring(uid))
  end
  function TOOL:ClearActor() RunConsoleCommand('bgn_debug_clear') end
  function TOOL:PinActor() RunConsoleCommand('bgn_debug_pin') end
  function TOOL.BuildCPanel(panel) bgNPC.DebugInspector.BuildPanel(panel) end
end
