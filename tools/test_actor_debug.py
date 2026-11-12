"""Actor inspector permission/lifecycle regressions: python tools/test_actor_debug.py (lupa)."""
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
lua = LuaRuntime()
lua.execute('''
now=10; enabled=true; hooks={}; timers={}; receivers={}; sent={}; registry={}
function CurTime() return now end
function IsValid(v) return type(v)=='table' and v.valid==true end
function isnumber(v) return type(v)=='number' end
function isbool(v) return type(v)=='boolean' end
function GetConVar() return {GetBool=function() return enabled end} end
hook={Add=function(name,id,f) hooks[name]=f end}
timer={Create=function(name,_,_,f) timers[name]=f end}
bgNPC={DebugInspector={},Actors={},Brain={Resolve=function() return 'goap' end},
    Util={IsInView=function() return false end},Vision={HasLineOfSight=function() return true end},Net={}}
function bgNPC.Actors.Get(ent) return ent and ent.actor end
function bgNPC.Actors.GetByUid(uid) return registry[uid] end
function bgNPC.Net.Receive(name,f,opts) receivers[name]={f=f,opts=opts} end
function bgNPC.Net.Send(name,ply,data) sent[#sent+1]={name=name,ply=ply,data=data} end
function AddOriginToPVS(pos) pvs=pos end
function Player(admin)
    local p={valid=true,bgn_ready=true,admin=admin,alive=true}
    function p:IsPlayer() return true end
    function p:Nick() return 'test player' end
    function p:IsAdmin() return self.admin end
    function p:IsSuperAdmin() return false end
    function p:Alive() return self.alive end
    function p:WorldSpaceCenter() return 'observer position' end
    function p:GetClass() return 'player' end
    function p:EntIndex() return 100 end
    return p
end
function NPC()
    local n={valid=true}
    function n:EyePos() return 'eyes' end
    function n:GetAimVector() return {Angle=function() return 'angles' end} end
    function n:WorldSpaceCenter() return 'center' end
    function n:WorldToLocal(v) return v end
    function n:WorldToLocalAngles(v) return v end
    return n
end
function Actor(uid)
    local a={uid=uid,alive=true,data={team={'residents'},at_damage={fear=90,defense=10}},
        state_delay=11,lod=1,enemies={},targets={},walkPath={'p1'}}
    a.npc=NPC(); a.npc.actor=a
    function a:IsAlive() return self.alive end
    function a:GetNPC() return self.npc end
    function a:GetType() return 'citizen' end
    function a:GetState() return 'fear' end
    function a:GetOldState() return 'walk' end
    function a:GetStateGroupName() return 'danger' end
    function a:GetLastReaction() return 'fear' end
    function a:Health() return 20 end
    function a:GetMaxHealth() return 30 end
    function a:IsStateLock() return false end
    function a:IsWanted() return false end
    function a:IsStayingOut() return true end
    function a:GetActiveWeapon() return nil end
    a.brain={Describe=function() return 'goal/plan/facts' end,
        Sense=function() error('inspection must not run sensors') end,
        Update=function() error('inspection must not advance AI') end}
    a.GetReactionForDamage=function() error('inspection must not roll a reaction') end
    registry[uid]=a
    return a
end
admin=Player(true); guest=Player(false); actor=Actor(1)
cmd={ClearMovement=function() cleared_move=true end,ClearButtons=function() cleared_buttons=true end}
''')
lua.execute(r"""
SERVER=true
function istable(v) return type(v)=='table' end
function SysTime() return now end
math.Clamp=function(v,a,b) return math.max(a,math.min(b,v)) end
function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
function table.Empty(t) for k in pairs(t) do t[k]=nil end end
actor.isBgnClass=true
function actor.npc:IsPlayer() return false end
function actor.npc:EntIndex() return 1 end
function actor.npc:GetPos() return 'position' end
function actor.npc:GetAngles() return 'angle' end
function actor.npc:OBBMins() return 'mins' end
function actor.npc:OBBMaxs() return 'maxs' end
function actor.npc:GetSequence() return 1 end
function actor.npc:GetSequenceName() return 'idle' end
function actor.npc:GetModel() return 'model' end
function actor.npc:IsNextBot() return false end
function actor:InVehicle() return false end
function actor:Walking() return false end
function actor:GetPos() return self.npc:GetPos() end
bgNPC.Vision.HasLineOfSight=function() error('debug snapshot must not trace') end
bgNPC.Util.IsInView=function() error('debug snapshot must not sample vision') end
""")
for name in ('sh_actor_inspector.lua', 'sv_actor_events.lua', 'sv_actor_inspector.lua'):
    lua.execute((ROOT / 'lua/background_npcs_core/debug' / name).read_text(encoding='utf-8-sig'), name=name)
lua.execute(r"""
local I=bgNPC.DebugInspector
local receiver=receivers['bgn.debug_select']
assert(receiver.opts.admin)
local function select(ply,uid,watch,opts) receiver.f(ply,uid,watch,opts or {vision=true,signals=true,path=true}) end
local function tick() timers.BGN_Debug_Inspector() end
select(guest,1,true); tick(); assert(#sent==0)
select(admin,{},true); select(admin,1,'yes'); tick(); assert(#sent==0)
enabled=false; select(admin,1,true); tick(); assert(#sent==0)
enabled=true; select(admin,1,false); tick()
local d=sent[#sent].data
assert(d.uid==1 and d.eye_local=='eyes' and d.plan=='goal/plan/facts')
assert(#d.sights==0 and #d.events==0 and d.observer==nil,'no synthetic observer tests')
I.Emit(actor,'damage',admin,'fear')
I.Sight(actor.npc,admin,false,'witness',nil,nil)
now=11; select(admin,1,false); tick(); d=sent[#sent].data
assert(#d.events==1 and #d.sights==1 and d.sights[1].visible==false)
for j=1,300 do I.Emit(actor,'state',nil,tostring(j)) end
local events=I.Export(actor,30)
assert(#events==256 and events[#events].reason=='300','bounded event ring preserves newest data')
local _,_,dropped=I.Export(actor,30) assert(dropped==45,'ring overwrites are reported')
I.Sight(actor.npc,admin,false,'view',{StartPos='eyes',HitPos='wall',HitWorld=true},true)
local _,sights=I.Export(actor,30)
local found=false for _,r in ipairs(sights) do if r.channel=='view' then found=r.blocker=='world' and r.direction~=nil end end
assert(found,'map geometry and actual view direction are recorded')
select(admin,1,false,{rate=0/0,related=math.huge,seconds=-10,path=true})
assert(I.selections[admin].rate==5 and I.selections[admin].related==64 and I.selections[admin].seconds==1)
actor.walkPath={} for j=1,300 do actor.walkPath[j]='p' end
now=12; tick(); d=sent[#sent].data
assert(#d.path==256 and d.hidden_path==44,'snapshot caps path size')
local serial=I.sessions[1].serial
actor.npc.valid=false; I.Emit(actor,'state',nil,'body replacement')
assert(I.sessions[1].serial==serial,'missing body during replacement is safe')
actor.npc.valid=true
select(admin,1,true); hooks.SetupPlayerVisibility(admin); assert(pvs=='eyes')
hooks.StartCommand(admin,cmd); assert(cleared_move and cleared_buttons)
now=15; cleared_move=false; hooks.StartCommand(admin,cmd); assert(not cleared_move,'expired subscription releases inputs')
assert(not I.Observed(actor),'events have no consumer after expiry')
select(admin,1,true); admin.admin=false
cleared_move=false; hooks.StartCommand(admin,cmd); assert(not cleared_move)
admin.admin=true; select(admin,1,true); actor.alive=false
now=16; tick(); assert(sent[#sent].data==nil,'removed actor clears client selection')
actor.alive=true; select(admin,1,true); select(admin,nil)
cleared_move=false; hooks.StartCommand(admin,cmd); assert(not cleared_move)
""")
print('PASS: subscriptions, event ring, permissions, no debug traces, snapshot and camera lifecycle')

# Compile the new portable Lua files in both realms; rendering still needs a live GMod check.
for name in ('sh_actor_inspector.lua', 'sv_actor_inspector.lua', 'sv_actor_events.lua', 'cl_actor_visuals.lua', 'cl_actor_fonts.lua', 'cl_actor_inspector.lua'):
    source = (ROOT / 'lua/background_npcs_core/debug' / name).read_text(encoding='utf-8-sig')
    lua.execute('assert(loadstring(...))', source)

phrases = {}
for lang in ('en', 'ru'):
    lines = (ROOT / f'resource/localization/{lang}/bgn_debug.properties').read_text(encoding='utf-8').splitlines()
    keys = [line.split('=', 1)[0] for line in lines if '=' in line]
    assert len(keys) == len(set(keys)), f'Duplicate {lang} phrases'
    phrases[lang] = set(keys)
assert phrases['en'] == phrases['ru'], 'EN/RU controls must match'
print('PASS: inspector Lua syntax and EN/RU localization keys')

client = LuaRuntime()
client.execute('''
now=10; enabled=true; admin=true; alive=true; hooks={}; commands={}; callbacks={}; receivers={}; sent={}
function RealTime() return now end
function IsValid(v) return type(v)=='table' and v.valid end
function GetConVar(name) return {GetBool=function() return name~='bgn_cl_debug_freeze' and enabled end,GetFloat=function() return text_scale or 1 end} end
function Color() return {} end
function ScrH() return 900 end
math.Clamp=function(v,a,b) return math.max(a,math.min(b,v)) end
math.Round=function(v) return math.floor(v+0.5) end
fonts={}
surface={CreateFont=function(name,data) fonts[name]=data end,SetFont=function() end,
    GetTextSize=function(text) return #text*10 end}
local vec={}; vec.__index=vec
function Vector(x) return setmetatable({x=x or 0},vec) end
function vec.__add(a,b) return Vector(a.x+b.x) end
function vec.__mul(a,b) return Vector(a.x*b) end
angles={Forward=function() return Vector(1) end}
ply={valid=true,IsAdmin=function() return admin end,IsSuperAdmin=function() return false end,
    Alive=function() return alive end,GetEyeTrace=function() return {} end}
function LocalPlayer() return ply end
bgNPC={debug_settings={},DebugInspector={},Actors={Get=function() end},Net={}}
bgNPC.Net.SendToServer=function(name,uid,watch) sent[#sent+1]={uid=uid,watch=watch} end
bgNPC.Net.Receive=function(name,f) receivers[name]=f end
hook={Add=function(name,id,f) hooks[name]=f end}
concommand={Add=function(name,f) commands[name]=f end}
cvars={AddChangeCallback=function(name,f) callbacks[name]=f end}
input={IsKeyDown=function() return key_down end}
gui={IsGameUIVisible=function() return menu_open end}
language={GetPhrase=function(key) return key end}
notification={AddLegacy=function() end}
cmd={ClearMovement=function() moved=true end,ClearButtons=function() buttons=true end}
''')
client.execute((ROOT / 'lua/background_npcs_core/debug/sh_actor_inspector.lua').read_text(encoding='utf-8'))
client.execute((ROOT / 'lua/background_npcs_core/debug/cl_actor_fonts.lua').read_text(encoding='utf-8'))
client.execute((ROOT / 'lua/background_npcs_core/debug/cl_actor_inspector.lua').read_text(encoding='utf-8'))
client.execute('''
local I=bgNPC.DebugInspector
assert(fonts[I.font].size==20 and I.line_height==24, 'readable default at 900p')
text_scale=1.5; callbacks.bgn_cl_debug_text_scale()
assert(fonts[I.font].size==30 and I.line_height==36, 'text scale updates font and spacing')
text_scale=1; callbacks.bgn_cl_debug_text_scale()
local wrapped=I.WrapLines({'first second third'},120)
assert(#wrapped==2 and wrapped[1]=='first second' and wrapped[2]=='third', 'wrap text instead of clipping it')
local function select(uid) commands.bgn_debug_select(nil,nil,{tostring(uid)}) end
local function snapshot(uid) receivers['bgn.debug_detail'](nil,{uid=uid,eye=Vector(100),angles=angles}) end
select(1); snapshot(2); assert(I.detail==nil, 'discard stale snapshot for a different actor')
snapshot(1); assert(I.detail.uid==1)
assert(hooks.CalcView(nil,nil,nil,90)==nil, 'selection alone does not replace camera')
commands.bgn_debug_watch(); snapshot(1)
local view=hooks.CalcView(nil,nil,nil,90)
assert(view.origin.x==108 and view.fov==90, 'camera follows actor eyes without moving player')
local body={valid=true,base=100,IsDormant=function() return false end}
function body:EyePos() return Vector(self.base) end -- NextBot client eyes default to its feet.
function body:LocalToWorld(v) return Vector(self.base+v.x) end
function body:LocalToWorldAngles(v) return v end
I.detail.entity=body; I.detail.eye_local=Vector(62); I.detail.aim_local=angles
assert(hooks.CalcView(nil,nil,nil,90).origin.x==170, 'NextBot camera must use server eye height, not client feet')
body.base=200
assert(hooks.CalcView(nil,nil,nil,90).origin.x==270, 'server eye offset follows client body interpolation')
local original=function() original_draws=(original_draws or 0)+1 end
body.RenderOverride=original
hooks.PreRender(); body:RenderOverride()
assert(original_draws==nil, 'viewed body must not clip into the first-person camera')
commands.bgn_debug_watch_stop(); body:RenderOverride()
assert(original_draws==1, 'normal body drawing resumes immediately on camera exit')
hooks.PreRender()
assert(body.RenderOverride==original, 'camera restores the existing renderer without changing NoDraw')
commands.bgn_debug_watch(); snapshot(1)
hooks.CreateMove(cmd); assert(moved and buttons, 'camera blocks accidental movement and attacks')
key_down=true; hooks.Think(); assert(not I.watching and I.uid==1, 'F6 returns to own view')
key_down=false; commands.bgn_debug_watch(); snapshot(1)
menu_open=true; hooks.Think(); assert(not I.watching, 'Escape releases camera')
menu_open=false; commands.bgn_debug_watch(); snapshot(1)
alive=false; hooks.Think(); assert(not I.watching, 'player death releases camera')
alive=true; snapshot(1); now=14; hooks.Think(); assert(I.uid==nil, 'lost server snapshots release selection')
select(1); snapshot(1); admin=false; hooks.Think(); assert(I.uid==nil, 'revoked rights clear local inspection')
admin=true; select(1); snapshot(1); enabled=false; hooks.Think(); assert(I.uid==nil)
enabled=true; select(1); callbacks.bgn_debug(); assert(I.uid==nil)
select(1); hooks.PostCleanupMap(); assert(I.uid==nil and #I.rows==0)
spawnmenu={AddToolMenuOption=function(tab,category,id,title,_,_,build)
    assert(tab=='Options' and category=='Background NPCs' and id=='BGN_Debug')
    build_panel=build
end}
hooks.PopulateToolMenu()
local controls={}
local combo={Clear=function() end}
function combo:AddChoice(_,uid,selected) if selected then self:OnSelect(nil,nil,uid) end end
local buttons={}
local panel={ClearControls=function() end,Help=function() return {SetText=function() end} end,
    CheckBox=function(_,_,name) controls[name]=true end,
    NumSlider=function(_,_,name) controls[name]=true end,
    AddItem=function() end,ComboBox=function() return combo end,Button=function(_,text) local b={} buttons[text]=b return b end}
vgui={Create=function() return {SetName=function() end,SetExpanded=function() end,CheckBox=function() end,NumSlider=function() end,TextEntry=function() end} end}
build_panel(panel)
for _,name in ipairs({'bgn_debug','bgn_cl_draw_npc_path','bgn_cl_debug_bounds','bgn_cl_debug_labels',
    'bgn_cl_debug_signals','bgn_cl_debug_inspector','bgn_cl_debug_vision','bgn_cl_debug_history'}) do
    assert(controls[name], 'debug page must include '..name)
end
assert(controls.bgn_cl_debug_text_scale)
select(1); snapshot(1); commands.bgn_debug_watch(); snapshot(1)
I.rows={{uid=1,type='citizen',state='idle'}}
buttons['bgn.debug.refresh']:DoClick()
assert(I.watching and I.detail.uid==1, 'refresh must not reset an already selected actor or camera')
admin=false; controls={}; build_panel(panel); assert(next(controls)==nil, 'debug menu is admin-only')
''')
print('PASS: client camera, stale replies, F6/Escape, death, timeouts, permission revocation and Spawnmenu controls')

client.execute('''
function GetConVar() return {GetBool=function() return true end,GetFloat=function() return 500 end} end
function tobool(v) return v==true or v=='1' end
local vec=getmetatable(Vector())
function vec:DistToSqr() return 1000000 end
function ply:GetPos() return Vector() end
npc={valid=true,hidden=false}
function npc:GetPos() return Vector(1000) end
function npc:GetActiveWeapon() return nil end
function npc:GetNW2Bool() return knocked_down or false end
function npc:GetNoDraw() return self.hidden end
function npc:SetNoDraw(value) self.hidden=value end
actor={carry_visual=nil,IsAlive=function() return true end,GetNPC=function() return npc end,
    InVehicle=function() return false end}
bgNPC.Actors.GetAll=function() return {actor} end
bgNPC.Util={IsInView=function() return false end}
bgNPC.Animator={IsPlaying=function() return false end}
bgNPC.Tasks={Add=function(_,f) optimize=f end}
bgNPC.DebugInspector.IsWatching=function() return remote_camera end
''')
# The sole GLua continue is in the disabled branch, which these enabled cases never enter.
optimization = (ROOT / 'lua/background_npcs_core/systems/cl_render_optimization.lua').read_text(encoding='utf-8-sig')
client.execute(optimization.replace('      continue', '      break'))
client.execute('''
local task=coroutine.create(function() optimize(coroutine.yield,coroutine.yield,function() end) end)
local function tick() local ok,err=coroutine.resume(task); assert(ok,err) end
tick(); assert(npc.hidden, 'ordinary view optimization still hides actors behind the player')
remote_camera=true; tick(); assert(not npc.hidden, 'remote actor view releases local view hiding')
knocked_down=true; tick(); assert(npc.hidden, 'remote camera must preserve server-owned hiding')
knocked_down=false; remote_camera=false; tick(); assert(npc.hidden, 'normal optimization resumes after camera exit')
''')
print('PASS: remote camera rendering bypass preserves ordinary culling and server-owned hiding')
# Real mover methods: permissions, exclusive control and restoration on every release path.
mover = LuaRuntime()
mover.execute('''
SERVER=true; CLIENT=false; now=10; TOOL={}; owner={valid=true,admin=true}
function IsValid(v) return type(v)=='table' and v.valid end
function owner:IsAdmin() return self.admin end
function owner:IsSuperAdmin() return false end
function CurTime() return now end
math.Clamp=function(n,a,b) return math.max(a,math.min(b,n)) end
actor={alive=true,debugger=false,eternal=false,locked=false,state='walk',data={token=1},walkPath={}}
function actor:IsAlive() return self.alive end
function actor:InVehicle() return false end
function actor:IsStateLock() return self.locked end
function actor:StateLock(v) self.locked=v end
function actor:GetState() return self.state end
function actor:GetStateData() return self.data end
function actor:SetState(v,data) self.state,self.data=v,data end
function actor:StopWalk() self.stopped=true end
function actor:GetPos() return {DistToSqr=function() return 100000 end} end
function actor:WalkToPos(p,speed) self.destination=p self.speed=speed end
bgNPC={Actors={Get=function() return actor end},Net={ToolRPC=function() end}}
function TOOL:GetOwner() return owner end
function TOOL:GetClientInfo(k) return k=='speed' and 'run' or '48' end
''')
mover.execute((ROOT / 'lua/weapons/gmod_tool/stools/bgn_actor_mover.lua').read_text(encoding='utf-8-sig'))
mover.execute('''
local tr={Entity={},Hit=true,HitPos={}}
assert(not TOOL:RightClick(tr), 'destination needs a selected actor')
owner.admin=false; assert(not TOOL:LeftClick(tr))
owner.admin=true; actor.debug_move_owner={}; assert(not TOOL:LeftClick(tr), 'another owner cannot be overridden')
actor.debug_move_owner=nil
assert(TOOL:LeftClick(tr) and actor.debugger and actor.locked and not actor.eternal)
assert(TOOL:RightClick(tr)); TOOL:Think(); assert(actor.destination==tr.HitPos and actor.speed=='run')
TOOL:Holster()
assert(actor.state=='walk' and actor.data.token==1 and not actor.locked and not actor.debugger and not actor.eternal)
assert(not actor.debug_move_owner and not TOOL.Actor and not TOOL.Destination)
assert(TOOL:LeftClick(tr)); owner.admin=false; TOOL:Think()
assert(not TOOL.Actor and actor.state=='walk' and not actor.debugger, 'lost rights release control')
owner.admin=true; assert(TOOL:LeftClick(tr)); actor.alive=false; TOOL:Think()
assert(not actor.debug_move_owner and not actor.debugger and not actor.locked, 'death releases saved flags')
''')
print('PASS: mover permissions, exclusive ownership, path request, holster/revocation/death restoration')
# Language sync sends one cvar value, not both returns (code and display name).
language_sync = LuaRuntime()
language_sync.execute("""
bgNPC={Util={GetLanguage=function() return 'ru','russian' end}}
Util=bgNPC.Util
function RunConsoleCommand(...) assert(select('#',...)==2); local name,code=...; assert(name=='bgn_cl_language' and code=='ru') end
""")
util_source=(ROOT / 'lua/background_npcs_core/core/sh_util.lua').read_text(encoding='utf-8-sig')
sync=util_source[util_source.index('  local function SyncLanguage()'):util_source.index("  cvars.AddChangeCallback('gmod_language'")]
language_sync.execute(sync+'\nSyncLanguage()')
print('PASS: language synchronization sends only the language code')
