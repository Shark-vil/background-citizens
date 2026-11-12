local I = bgNPC.DebugInspector
if I.DestroyMeshes then I.DestroyMeshes() end
local meshes, tool_paths = {}, {}
local text_lines, full_text, cards, cached_hint = {}, '', {}, {}
local actor_matches = true
local palette = {path=Color(100,190,255), sight=Color(90,230,150), blocked=Color(255,100,90), signal=Color(255,200,70), memory=Color(180,150,255)}
local normal_mat = CreateMaterial('BGN_DebugBatch', 'UnlitGeneric', {['$vertexcolor']=1,['$vertexalpha']=1})
local wh_mat = CreateMaterial('BGN_DebugBatchWH', 'UnlitGeneric', {['$vertexcolor']=1,['$vertexalpha']=1,['$ignorez']=1})
I.stats = {build_ms=0, render_ms=0, segments=0, cards=0, builds=0}
local T = I.Text
local cv_cache={}
local function CV(name)
  if not cv_cache[name] then cv_cache[name]=GetConVar('bgn_cl_debug_'..name) end
  return cv_cache[name]
end
local function Destroy(key)
  if meshes[key] then meshes[key]:Destroy() meshes[key]=nil end
end
function I.DestroyMeshes() for key in pairs(meshes) do Destroy(key) end end
function I.ResetVisuals()
  Destroy('actor')
  text_lines, full_text, cards = {}, '', {}
end
local function Build(key, lines)
  Destroy(key)
  if #lines==0 then return end
  local obj=Mesh()
  mesh.Begin(obj, MATERIAL_LINES, #lines)
  for _, line in ipairs(lines) do
    for j=1,2 do mesh.Position(line[j]) mesh.Color(line[3].r,line[3].g,line[3].b,255) mesh.AdvanceVertex() end
  end
  mesh.End()
  meshes[key]=obj
end
local function Line(lines,a,b,c)
  if not a or not b then return end
  if #lines<1024 then lines[#lines+1]={a,b,c} else lines.dropped=(lines.dropped or 0)+1 end
end
local function Arrow(lines,a,b,c)
  Line(lines,a,b,c)
  local d=(b-a):GetNormalized()
  local right=d:Cross(Vector(0,0,1))
  Line(lines,b,b-d*14+right*7,c) Line(lines,b,b-d*14-right*7,c)
end
local function Cross(lines,p,size)
  for _,axis in ipairs({Vector(size,0,0),Vector(0,size,0),Vector(0,0,size)}) do Line(lines,p-axis,p+axis,palette.blocked) end
end
local function Bounds(lines,d)
  local corners={}
  for x=0,1 do for y=0,1 do for z=0,1 do
    local v=Vector(x==0 and d.mins.x or d.maxs.x,y==0 and d.mins.y or d.maxs.y,z==0 and d.mins.z or d.maxs.z)
    corners[x*4+y*2+z+1]=LocalToWorld(v,angle_zero,d.pos,d.ang)
  end end end
  for j=0,7 do for _,mask in ipairs({1,2,4}) do
    local other=bit.bxor(j,mask)
    if other>j then Line(lines,corners[j+1],corners[other+1],palette.path) end
  end end
end
local function State(name)
  local value=T('state.'..name)
  return value=='bgn.debug.state.'..name and name or value
end
I.State = State
local function Event(e, now)
  local key='event.'..e.kind
  local label=T(key)
  if label=='bgn.debug.'..key then label=e.kind end
  local result=e.accepted==nil and '' or (' ['..T(e.accepted and 'accepted' or 'rejected')..']')
  if e.kind=='state' then
    local before,after=(e.reason or ''):match('^(.-) %-> (.-)$')
    if before then return label..': '..State(before)..' -> '..State(after) end
  end
  if e.source~='-' then return label..': '..e.source..' -> '..e.actor..' | '..T('about')..' '..e.target..result..(e.reason=='reaction_blocked' and (' | '..T('reaction_blocked')) or '') end
  return string.format('%.1fs %s: %s -> %s%s %s',math.max(0,now-e.time),label,e.actor,e.target,result,e.kind=='pick' and State(e.reason) or (e.reason or ''))
end
local function Matches(d)
  for _,pair in ipairs({{'team_filter','team'},{'type_filter','type'},{'state_filter','state'}}) do
    local query=CV(pair[1]):GetString():lower()
    if query~='' and not tostring(d[pair[2]] or ''):lower():find(query,1,true) then return false end
  end
  return true
end
local function Weights(t)
  local result={}
  for k,v in SortedPairs(t or {}) do result[#result+1]=k..'='..v end
  return table.concat(result,', ')
end
function I.OnSnapshot(d)
  local begin=SysTime()
  actor_matches=Matches(d)
  I.stats.builds=I.stats.builds+1
  local now=CV('freeze'):GetBool() and d.time or CurTime()
  local technical=CV('technical'):GetBool()
  text_lines={d.name..' | '..State(d.state),
    string.format('HP %d/%d | %s: %s | %s: %s',d.hp,d.max_hp,T('team'),d.team,T('weapon'),d.weapon),
    T('reaction')..': '..(d.reaction and d.reaction~='' and State(d.reaction) or T('unknown')),
    string.format('%s: %d | %s: %d | %s: %s',T('enemies'),d.enemy_count or #d.enemies,T('targets'),d.target_count or #d.targets,T('wanted'),T(d.wanted and 'yes' or 'no'))}
  if d.locked or d.delay>0 then text_lines[#text_lines+1]=T('locked')..': '..T(d.locked and 'yes' or 'no')..' | '..T('delay')..': '..string.format('%.1fs',d.delay) end
  text_lines[#text_lines+1]=T('movement')..': '..T(d.walking and 'moving' or 'stopped')..' | '..T('path_points')..': '..#d.path
  if technical then text_lines[#text_lines+1]=d.state..' | '..d.body..'/'..d.brain..' | LOD '..tostring(d.lod) end
  local details=table.Copy(text_lines)
  details[#details+1]=T('state')..': '..d.state..' / '..d.group
  details[#details+1]=T('staying_out')..': '..T(d.staying_out and 'yes' or 'no')
  details[#details+1]=T('model')..': '..d.model
  details[#details+1]=T('animation')..': '..d.sequence..' | '..T('carry')..': '..d.carry
  details[#details+1]=T('plan')..': '..(d.plan~='' and d.plan or T('fsm.help'))
  details[#details+1]=T('damage_weights')..': '..Weights(d.damage_weights)
  details[#details+1]=T('protect_weights')..': '..Weights(d.protect_weights)
  for _,kind in ipairs({'enemies','targets'}) do
    for _,r in ipairs(d[kind]) do details[#details+1]=T(kind)..': '..r.name..' | '..T('known')..' | '..T('last_seen')..': '..(r.last_seen and string.format('%.1fs',now-r.last_seen) or T('not_checked')) end
  end
  local lines={}
  if CV('bounds'):GetBool() then Bounds(lines,d) end
  if GetConVar('bgn_cl_draw_npc_path'):GetBool() then
    for j=2,#d.path do Line(lines,d.path[j-1],d.path[j],palette.path) end
    if d.path[1] then Line(lines,d.pos,d.path[1],palette.path) end
  end
  cards={{pos=d.eye+Vector(0,0,20),name=d.name,state=State(d.state),uid=d.uid}}
  if CV('overview'):GetBool() then
    for _,r in ipairs(I.rows) do
      if r.uid~=d.uid and Matches(r) and #cards<CV('related'):GetInt()+1 and r.pos:DistToSqr(d.pos)<=CV('geometry_distance'):GetFloat()^2 then
        if CV('bounds'):GetBool() then Bounds(lines,r) end
        cards[#cards+1]={pos=r.pos+Vector(0,0,90),name=r.type..' #'..r.uid,state=State(r.state)}
      end
    end
  end
  for _,r in ipairs(d.enemies) do
    if CV('targets'):GetBool() then Line(lines,d.eye,r.pos,palette.memory) end
    if #cards<CV('related'):GetInt()+1 then cards[#cards+1]={pos=r.pos+Vector(0,0,50),name=r.name,state=T('known')} end
  end
  local cone_drawn=false
  if CV('vision'):GetBool() then
    local shown=0
    if #d.sights==0 then text_lines[#text_lines+1]=T('vision')..': '..T('not_checked') end
    for _,r in ipairs(d.sights) do
      local age=now-r.time
      details[#details+1]=T('channel.'..r.channel)..': '..r.target..' | '..T(r.visible and 'visible' or 'not_visible')..' | '..(r.blocker=='world' and T('world') or r.blocker)..' | '..string.format('%.1fs',age)
      if shown<2 and age<=CV('life'):GetFloat() then
        text_lines[#text_lines+1]=T('channel.'..r.channel)..': '..r.target..' -> '..T(r.visible and 'visible' or (r.in_view==false and 'outside_view' or 'not_visible'))
        shown=shown+1
      end
      if age<=CV('life'):GetFloat() then
        Line(lines,r.from,r.to,r.visible and palette.sight or palette.blocked)
        if CV('blockers'):GetBool() and r.hit and not r.visible then Cross(lines,r.hit,CV('marker_size'):GetFloat()) end
        -- Only the real view-vector test has this cone. Plain LOS channels remain omnidirectional.
        if r.direction and not cone_drawn then
          cone_drawn=true
          local ang=r.direction:Angle()
          local half=math.acos(math.pi/90)
          local previous
          for j=0,16 do
            local a=j*math.pi/8
            local point=r.from+(ang:Forward()*math.cos(half)+(ang:Right()*math.cos(a)+ang:Up()*math.sin(a))*math.sin(half))*100
            if previous then Line(lines,previous,point,palette.sight) end
            if j%4==0 then Line(lines,r.from,point,palette.sight) end
            previous=point
          end
        end
      end
    end
  end
  local recent={}
  local filter=CV('event_filter'):GetString():lower()
  for _,e in ipairs(d.events) do
    if (e.source=='-' or CV('signals'):GetBool()) and (filter=='' or e.kind:find(filter,1,true)) then
      local label=Event(e,now)
      details[#details+1]=label
      recent[#recent+1]=label
      if e.source~='-' and CV('signals'):GetBool() and now-e.time<=CV('life'):GetFloat() then Arrow(lines,e.from,e.to,e.accepted==false and palette.blocked or palette.signal) end
    end
  end
  if CV('history'):GetBool() then
    for j=math.max(1,#recent-4),#recent do text_lines[#text_lines+1]=recent[j] end
  end
  local limited=(d.dropped or 0)+(d.hidden_relations or 0)+(d.hidden_path or 0)+(lines.dropped or 0)+(CV('overview'):GetBool() and (I.roster_dropped or 0) or 0)
  if limited>0 then text_lines[#text_lines+1]=T('limited')..': '..limited end
  full_text=table.concat(details,'\n')
  local occupied={}
  for _,card in ipairs(cards) do
    card.lines=I.WrapLines({card.name,card.state},300)
    local screen=card.pos:ToScreen()
    card.show=screen.visible
    for _,point in ipairs(occupied) do if math.abs(screen.x-point.x)<320 and math.abs(screen.y-point.y)<90 then card.show=false break end end
    if card.show then occupied[#occupied+1]=screen end
  end
  text_lines=I.WrapLines(text_lines,math.min(900,ScrW()*.48)-24)
  cached_hint=I.WrapLines({T('watch.help')},ScrW()-60)
  Build('actor',lines)
  I.stats.segments=#lines
  I.stats.build_ms=(SysTime()-begin)*1000
end
function I.SetToolPath(id,path)
  local lines={}
  for j=2,#path do Line(lines,path[j-1],path[j],palette.path) end
  if path[1] then Cross(lines,path[1],6) end
  if path[#path] and #path>1 then Cross(lines,path[#path],10) end
  tool_paths[id]=path
  Build(id,lines)
end
function I.ToolControls(panel)
  panel:CheckBox(T('enable'),'bgn_debug')
  panel:NumSlider(T('text_scale'),'bgn_cl_debug_text_scale',.75,2,2)
  for _,name in ipairs({'distance','geometry_distance','marker_size'}) do
    panel:NumSlider(T(name),'bgn_cl_debug_'..name, name=='marker_size' and 2 or 100,name=='marker_size' and 48 or 5000,0)
  end
  panel:CheckBox(T('wh'),'bgn_cl_debug_wh')
  panel:CheckBox(T('markers'),'bgn_cl_debug_markers')
  panel:Button(T('details'),'bgn_debug_tool_details')
end
function I.ToolReport(text)
  if I.report_source==text then return end
  I.report_source=text
  I.report_lines=I.WrapLines(string.Explode('\n',text),math.min(700,ScrW()*.45))
end
function I.DrawToolReport(text)
  if not I.Allowed() then return end
  I.ToolReport(text)
  local lines=I.report_lines or {}
  local y=ScrH()*.45
  local count=math.min(#lines,math.floor((ScrH()-y-30)/I.line_height))
  draw.RoundedBox(4,16,y-8,math.min(740,ScrW()*.48),count*I.line_height+16,Color(0,0,0,210))
  for j=1,count do draw.SimpleText(j==count and #lines>count and T('overflow') or lines[j],I.font,24,y+(j-1)*I.line_height,color_white) end
end
local function OpenText(get)
  if not I.Allowed() then return end
  if IsValid(I.window) then I.window:Remove() end
  local frame=vgui.Create('DFrame') I.window=frame
  frame:SetSize(math.min(1100,ScrW()-40),math.min(800,ScrH()-40)) frame:Center() frame:SetTitle(T('details')) frame:MakePopup()
  local entry=frame:Add('DTextEntry') entry:Dock(FILL) entry:SetMultiline(true) entry:SetEditable(false) entry:SetFont(I.font)
  frame.Think=function() if not entry:HasFocus() and entry:GetValue()~=get() then entry:SetText(get()) end end
end
concommand.Add('bgn_debug_details',function() OpenText(function() return full_text end) end)
concommand.Add('bgn_debug_tool_details',function() OpenText(function() return I.report_source or '' end) end)
hook.Add('PostDrawHUD','BGN_Debug_Inspector',function()
  if not I.Allowed() then return end
  if I.watching then for j,line in ipairs(cached_hint) do draw.SimpleTextOutlined(line,I.font,ScrW()/2,20+(j-1)*I.line_height,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,color_black) end end
  local d=I.detail
  if not d or not GetConVar('bgn_cl_debug_inspector'):GetBool() or CV('mode'):GetInt()~=0 or not actor_matches then return end
  local width=math.min(900,ScrW()*.48)
  local count=math.min(#text_lines,math.floor((ScrH()-200)/I.line_height))
  local x,y=ScrW()-width-16,100
  draw.RoundedBox(4,x,y,width,(count+2)*I.line_height+24,Color(0,0,0,210))
  for j=1,count do draw.SimpleText(j==count and #text_lines>count and T('overflow') or text_lines[j],I.font,x+12,y+12+(j-1)*I.line_height,color_white) end
  local status=CV('freeze'):GetBool() and T('recorded') or (CurTime()-d.time>2 and T('stale') or T('live'))
  status=string.format('%s %.1fs',status,math.max(0,CurTime()-d.time))
  if GetConVar('bgn_cl_debug_summary'):GetBool() then
    status=status..string.format(' | %s %.2fms / %.2fms | %d %s',T('cost'),d.collect_ms or 0,I.stats.render_ms,I.stats.segments,T('segments'))
  end
  draw.SimpleText(status,I.font,x+12,y+12+count*I.line_height,palette.path)
end)
hook.Add('PostDrawTranslucentRenderables','BGN_Debug_Batch',function(depth,sky)
  if depth or sky or not I.Allowed() then return end
  local begin=SysTime()
  I.stats.cards=0
  render.SetMaterial(CV('wh'):GetBool() and wh_mat or normal_mat)
  local d=I.detail
  if d and actor_matches and (CV('freeze'):GetBool() or CurTime()-d.time<2) then
    if meshes.actor and EyePos():DistToSqr(d.pos)<=CV('geometry_distance'):GetFloat()^2 then meshes.actor:Draw() end
    if CV('mode'):GetInt()==1 and CV('labels'):GetBool() then
      local used=0
      local angle=EyeAngles() angle:RotateAroundAxis(angle:Forward(),90) angle:RotateAroundAxis(angle:Right(),90)
      for _,card in ipairs(cards) do
        if card.show and used<CV('cards'):GetInt() and EyePos():DistToSqr(card.pos)<=CV('distance'):GetFloat()^2 then
          cam.Start3D2D(card.pos,angle,math.Clamp(EyePos():Distance(card.pos)/900,.15,.9))
          draw.RoundedBox(4,-160,-16,320,I.line_height*#card.lines+24,Color(0,0,0,210))
          for j,line in ipairs(card.lines) do draw.SimpleText(line,I.font,0,(j-1)*I.line_height,j==1 and color_white or palette.path,TEXT_ALIGN_CENTER) end
          cam.End3D2D() used=used+1
        end
      end
      I.stats.cards=used
    end
  end
  for id,path in pairs(tool_paths) do
    if path[1] and meshes[id] and bgNPC.Util.GetActivePlayerTool(id,LocalPlayer()) and EyePos():DistToSqr(path[1])<=CV('geometry_distance'):GetFloat()^2 then meshes[id]:Draw() end
  end
  if meshes.markers and I.marker_pos and EyePos():DistToSqr(I.marker_pos)<=CV('geometry_distance'):GetFloat()^2 then meshes.markers:Draw() end
  I.stats.render_ms=(SysTime()-begin)*1000
end)
local function Rebuild() if I.detail then I.OnSnapshot(I.detail) end end
for _,setting in ipairs(bgNPC.debug_settings) do
  cvars.AddChangeCallback('bgn_cl_debug_'..setting[1],Rebuild,'BGN_Debug_Rebuild')
end
for _,name in ipairs({'bgn_cl_debug_bounds','bgn_cl_debug_targets','bgn_cl_debug_vision','bgn_cl_debug_history','bgn_cl_draw_npc_path'}) do
  cvars.AddChangeCallback(name,Rebuild,'BGN_Debug_Rebuild')
end
hook.Add('ShutDown','BGN_Debug_MeshCleanup',function() for key in pairs(meshes) do Destroy(key) end end)

bgNPC.Net.Receive('bgn.debug_preview',function(_,data)
  data.received_at=RealTime() I.preview=data
end)
timer.Create('BGN_Debug_ToolMarkers',.5,0,function()
  Destroy('markers') I.marker_pos=nil
  if not I.Allowed() or not CV('markers'):GetBool() then return end
  local ply=LocalPlayer()
  local scene=bgNPC.Util.GetActivePlayerTool('bgn_scenic_debug',ply)
  local carry=bgNPC.Util.GetActivePlayerTool('bgn_carry_debug',ply)
  if not scene and not carry then return end
  local lines={}
  if scene then
    scene.PreviewText=T('preview')..': '..T('not_checked')
    bgNPC.Net.SendToServer('bgn.debug_preview',scene:GetClientInfo('scene'))
    local p=I.preview
    if p and p.pos and p.id==scene:GetClientInfo('scene') and RealTime()-p.received_at<1.5 then
      I.marker_pos=p.pos
      local c=p.valid and palette.sight or palette.blocked
      local size=CV('marker_size'):GetFloat()
      Line(lines,p.pos-Vector(size,0,0),p.pos+Vector(size,0,0),c)
      Line(lines,p.pos-Vector(0,size,0),p.pos+Vector(0,size,0),c)
      for _,slot in ipairs(p.positions or {}) do Bounds(lines,{pos=slot.pos,ang=slot.ang,mins=Vector(-16,-16,0),maxs=Vector(16,16,72)}) end
      scene.PreviewText=T('preview')..': '..T(p.valid and 'compatible' or 'incompatible')..' | '..(p.valid and T('preview.help') or tostring(p.message))
    end
  else
    carry.ReportText=T('aim.help')
    local n=ply:GetEyeTrace().Entity
    if not IsValid(n) or not bgNPC.Actors.Get(n) then return end
    I.marker_pos=n:GetPos()
    local size=CV('marker_size'):GetFloat()
    local kind=carry:GetClientInfo('item')
    carry.ReportText=T(bgNPC.CarryItems.Supports(n,kind) and 'compatible' or 'incompatible')..' | '..kind..'\n'..n:GetModel()..' | '..n:GetSequenceName(n:GetSequence())
    n:SetupBones()
    for _,bone in ipairs({'ValveBiped.Bip01_R_Finger11','ValveBiped.Bip01_R_Finger12','ValveBiped.Bip01_L_Finger12','ValveBiped.Bip01_R_Hand','ValveBiped.Bip01_L_Hand'}) do
      local id=n:LookupBone(bone)
      local m=id and n:GetBoneMatrix(id)
      if m then
        local p,ang=m:GetTranslation(),m:GetAngles()
        Line(lines,p,p+ang:Forward()*size,palette.blocked)
        Line(lines,p,p+ang:Right()*size,palette.sight)
        Line(lines,p,p+ang:Up()*size,palette.path)
      end
    end
    local a=bgNPC.Actors.Get(n)
    carry.ReportText=carry.ReportText..'\n'..T('carry')..': '..(a.carry_visual or '-')
    local prop=bgNPC.CarryItems.visuals and bgNPC.CarryItems.visuals[a]
    if IsValid(prop) then
      local pos,ang=prop:GetRenderOrigin() or prop:GetPos(),prop:GetRenderAngles() or prop:GetAngles()
      Bounds(lines,{pos=pos,ang=ang,mins=prop:OBBMins(),maxs=prop:OBBMaxs()})
      local finger=n:LookupBone('ValveBiped.Bip01_R_Finger11')
      local grip=finger and n:GetBoneMatrix(finger)
      if prop.bgn_kind=='suitcase' and grip then
        local handle=pos+ang:Up()*7.5
        Line(lines,handle,grip:GetTranslation(),palette.signal)
        carry.ReportText=carry.ReportText..'\n'..T('grip_error')..': '..string.format('%.2f HU',handle:Distance(grip:GetTranslation()))
      end
    end
  end
  Build('markers',lines)
end)
