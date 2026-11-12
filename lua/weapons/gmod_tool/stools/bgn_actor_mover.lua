TOOL.Category = 'Background NPCs Debug'
TOOL.Name = '#tool.bgn_actor_mover.name'
TOOL.Information = {{name='left'},{name='right'},{name='reload'}}
TOOL.ClientConVar = {speed='walk', tolerance='48'}
if SERVER then
  local function Allowed(p) return IsValid(p) and (p:IsAdmin() or p:IsSuperAdmin()) end
  function TOOL:Release()
    local a=self.Actor
    if a and self.Saved then
      a.debugger, a.eternal = self.Saved.debugger, self.Saved.eternal
      a:StateLock(self.Saved.locked)
      if a:IsAlive() then
        a:StopWalk()
        a:SetState(self.Saved.state,self.Saved.data,true)
      end
    end
    if a then bgNPC.Net.ToolRPC(self,'ClearMove') end
    if a and self.Saved and a.debug_move_owner==self.Saved.owner then a.debug_move_owner=nil end
    self.Actor,self.Saved,self.Destination=nil,nil,nil
  end
  function TOOL:LeftClick(tr)
    if not Allowed(self:GetOwner()) then return false end
    local a=bgNPC.Actors.Get(tr.Entity)
    if not a or not a:IsAlive() or a:InVehicle() or (a.debug_move_owner and a.debug_move_owner~=self:GetOwner()) then return false end
    self:Release()
    self.Actor=a
    self.Saved={owner=self:GetOwner(),debugger=a.debugger,eternal=a.eternal,locked=a:IsStateLock(),state=a:GetState(),data=a:GetStateData()}
    a.debug_move_owner=self:GetOwner()
    a:SetState('none',nil,true) a:StateLock(true) a.debugger=true
    bgNPC.Net.ToolRPC(self,'SelectActor',a.uid)
    return true
  end
  function TOOL:RightClick(tr)
    if not Allowed(self:GetOwner()) or not self.Actor or not tr.Hit then return false end
    self.Destination=tr.HitPos self.NextUpdate=0
    return true
  end
  function TOOL:Think()
    local a=self.Actor
    if not a then return end
    if not Allowed(self:GetOwner()) or not a:IsAlive() then self:Release() return end
    if not self.Destination or (self.NextUpdate or 0)>CurTime() then return end
    self.NextUpdate=CurTime()+.5
    local tolerance=math.Clamp(tonumber(self:GetClientInfo('tolerance')) or 48,16,200)
    if a:GetPos():DistToSqr(self.Destination)<=tolerance*tolerance then self.Destination=nil a:StopWalk() bgNPC.Net.ToolRPC(self,'ClearMove') return end
    a:WalkToPos(self.Destination,self:GetClientInfo('speed')=='run' and 'run' or 'walk')
    bgNPC.Net.ToolRPC(self,'MovementReport',a.walkPath,#a.walkPath>0)
  end
  function TOOL:Reload() if Allowed(self:GetOwner()) then self:Release() end return true end
  function TOOL:Holster() self:Release() return true end
else
  function TOOL:SelectActor(uid) RunConsoleCommand('bgn_debug_select',tostring(uid)) end
  function TOOL:MovementReport(path,ok)
    bgNPC.DebugInspector.SetToolPath('bgn_actor_mover',path)
    self.ReportText=bgNPC.DebugInspector.Text(ok and 'moving' or 'no_path')
  end
  function TOOL:ClearMove() bgNPC.DebugInspector.SetToolPath('bgn_actor_mover',{}) self.ReportText=bgNPC.DebugInspector.Text('stopped') end
  function TOOL:DrawHUD() if self.ReportText then bgNPC.DebugInspector.DrawToolReport(self.ReportText) end end
  function TOOL.BuildCPanel(panel)
    panel:Help('#tool.bgn_actor_mover.desc')
    local speed=panel:ComboBox(bgNPC.DebugInspector.Text('speed'),'bgn_actor_mover_speed')
    speed:AddChoice(bgNPC.DebugInspector.Text('walk'),'walk') speed:AddChoice(bgNPC.DebugInspector.Text('run'),'run')
    panel:NumSlider(bgNPC.DebugInspector.Text('tolerance'),'bgn_actor_mover_tolerance',16,200,0)
    bgNPC.DebugInspector.ToolControls(panel)
  end
end
