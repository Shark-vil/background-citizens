"""Run route/wanted/settings regressions outside GMod: python tools/test_regressions.py (requires lupa)."""
import json
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'lua/background_npcs_core'


def realm(server):
    lua = LuaRuntime(unpack_returned_tuples=True)

    def to_json(value):
        def convert(v):
            if not hasattr(v, 'items'):
                return v
            items = dict(v.items())
            if items and set(items) == set(range(1, len(items) + 1)):
                return [convert(items[i]) for i in range(1, len(items) + 1)]
            return {str(k): convert(x) for k, x in items.items()}
        return json.dumps(convert(value))

    lua.globals().json_encode = to_json
    lua.globals().json_decode = lambda s: lua.table_from(json.loads(s), recursive=True)
    lua.globals().SERVER = server
    lua.globals().CLIENT = not server
    lua.execute('''
        bit = require('bit')
        function istable(v) return type(v) == 'table' end
        function isstring(v) return type(v) == 'string' end
        function isnumber(v) return type(v) == 'number' end
        function isfunction(v) return type(v) == 'function' end
        local vec = {}; vec.__index = vec
        function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0}, vec) end
        function isvector(v) return getmetatable(v) == vec end
        function vec:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
        function vec:Distance(b) return math.sqrt(self:DistToSqr(b)) end
        function vec.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
        function vec.__eq(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
        math.Round = function(n,d) local s=10^(d or 0); return math.floor(n*s+0.5)/s end
        now=100; function CurTime() return now end; RealTime=CurTime
        function IsValid(v) return type(v)=='table' and v.valid == true end
        FCVAR_NONE=0; FCVAR_ARCHIVE=1; NOTIFY_ERROR=1; NOTIFY_GENERIC=0
        MASK_NPCWORLDSTATIC=1
        cv={}; changes={}; received={}; sent={}; commands={}; hooks={}; timers={}; tests={}; files={}
        function setcv(name,value)
            local c=GetConVar(name); local old=c.value; c.value=tostring(value)
            if old~=c.value then for _,f in pairs(changes[name] or {}) do f(name,old,c.value) end end
        end
        function CreateConVar(name,default)
            if cv[name] then return cv[name] end
            local c={value=tostring(default)}; cv[name]=c
            function c:GetString() return self.value end
            function c:GetFloat() return tonumber(self.value) end
            function c:GetInt() return math.floor(tonumber(self.value)) end
            function c:GetBool() return self:GetFloat()~=0 end
            return c
        end
        function GetConVar(name) return cv[name] or CreateConVar(name,30) end
        RunConsoleCommand=setcv
        cvars={AddChangeCallback=function(name,f,id) changes[name]=changes[name] or {}; changes[name][id]=f end}
        concommand={Add=function(name,f) commands[name]=f end, GetTable=function() return commands end}
        hook={Add=function(name,id,f) hooks[name]=hooks[name] or {}; hooks[name][id]=f end,
            Run=function(name,...) for _,f in pairs(hooks[name] or {}) do local v=f(...); if v~=nil then return v end end end}
        timer={Create=function(name,_,__,f) timers[name]=f end, Simple=function(_,f) timers[#timers+1]=f end}
        game={GetMap=function() return 'gm_test' end}
        util={TableToJSON=json_encode, JSONToTable=function(s) local ok,v=pcall(json_decode,s); if ok then return v end end,
            Compress=function(s) return s end, Decompress=function(s) return s end,
            Base64Encode=function(s) return s end, Base64Decode=function(s) return s end,
            TraceLine=function() return {Hit=false} end}
        string.GetExtensionFromFilename=function(s) return s:match('%.([^.]*)$') end
        string.Trim=function(s) return s:match('^%s*(.-)%s*$') end
        file={Exists=function(p) return files[p]~=nil end, Size=function(p) return #(files[p] or '') end,
            Read=function(p) return files[p] end, Write=function(p,v) files[p]=v end, CreateDir=function() end}
        file.Find=function(pattern)
            local dir=pattern:sub(1,-2); local result={}
            for path in pairs(files) do
                if path:sub(1,#dir)==dir and not path:sub(#dir+1):find('/',1,true) then
                    result[#result+1]=path:sub(#dir+1)
                end
            end
            return result,{}
        end
        player={GetHumans=function() return {} end}
        local modules={}
        list={Set=function(_,name,v) modules[name]=v end}
        admin={valid=true, IsAdmin=function() return true end, IsSuperAdmin=function() return false end,
            ChatPrint=function() end}
        function LocalPlayer() return admin end
        notification={AddLegacy=function() end}; surface={PlaySound=function() end}
        function MsgN() end
        bgNPC={Net={Receive=function(n,f,opts) received[n]={f=f,opts=opts} end,
            Send=function(...) sent[#sent+1]={...} end, SendToServer=function(...) sent[#sent+1]={...} end},
            Notice={Watch=function() end}, Test={Add=function(n,f) tests[n]=f end},
            Util={Log=function() end, Warning=function() end, Notify=function() end, Lang=function(t) return t.default end},
            Tasks={Budget=function() end}, Commands={list={}, Register=function(n,v)
                commands[n]=v.server or function() end; bgNPC.Commands.list[n]=v
            end},
            Modules={Get=function(n) return modules[n] end},
            Table={HasWhere=function(t,f) for k,v in pairs(t) do if f(k,v) then return true end end return false end},
            Combat={IsIgnored=function() return false end}, cfg={wanted={levels={5,5,10,10,15}}},
            Statistics={GetSum=function() return 0 end, Reset=function() end},
            Actors={Get=function() end, GetAll=function() return {} end, GetByTeam=function() return {} end},
            Vision={AnyActorSees=function() return true end, HasLineOfSight=function() return true end},
            Modes={IsPeaceful=function() return false end}}
        modules.player_arrest={RemoveTarget=function() end, CanArrest=function() return false end}
        modules.team_parent={HasParent=function() return false end}
    ''')
    return lua


def load(lua, *paths):
    for path in paths:
        lua.execute((ROOT / path).read_text(encoding='utf-8-sig'), name=path)


client = realm(False)
load(client, 'core/sh_cvars.lua')
client.execute('''
    bgNPC.CVars.Register('bgn_wanted_time',30)
    local calls=0; local previous,latest
    bgNPC.CVars.OnChange('bgn_wanted_time',function(_,old,new)
        calls=calls+1; previous,latest=old,new
    end,'regression')
    setcv('bgn_wanted_time',180)
    assert(calls==0 and sent[1][1]=='bgn.cvar_set')
    received['bgn.cvar'].f(nil,'bgn_wanted_time','180')
    assert(calls==1,'admin confirmation must notify even when the local cvar already matches')
    assert(previous=='30' and latest=='180')
    received['bgn.cvar'].f(nil,'bgn_wanted_time','180')
    assert(calls==1,'duplicate confirmation must not notify twice')
    admin.IsAdmin=function() return false end
    setcv('bgn_wanted_time',10)
    assert(GetConVar('bgn_wanted_time'):GetString()=='180' and calls==1,'unauthorized edit reverts')
    received['bgn.cvar'].f(nil,'bgn_wanted_time','45')
    assert(calls==2 and GetConVar('bgn_wanted_time'):GetString()=='45','remote server changes notify non-admins too')
''')
load(client, 'systems/wanted/sh_wanted_class.lua', 'systems/wanted/cl_wanted_sync.lua')
client.execute('''
    local target={valid=true}; local wanted=bgNPC.Modules.Get('wanted')
    received.bgn_module_wanted_AddWanted.f(nil,target,300)
    local w=wanted:GetWanted(target)
    assert(w.wait_time==300,'server duration wins over a stale client cvar')
    received.bgn_module_wanted_UpdateWaitTime.f(nil,target,290)
    assert(w.wait_time==290,'client must not clamp the server countdown')
    received.bgn_module_wanted_UpdateWanted.f(nil,target,600)
    assert(w.wait_time==600)
''')

server = realm(True)
load(server, 'core/sh_cvars.lua')
server.execute('''
    for _,name in ipairs({'bgn_enable_wanted_mode','bgn_wanted_police_instantly','bgn_arrest_mode'}) do
        bgNPC.CVars.Register(name,1)
    end
    bgNPC.CVars.Register('bgn_wanted_time',30)
    setcv('bgn_wanted_impunity_limit',5); setcv('bgn_spawn_radius_visibility',2500)
''')
load(server, 'systems/wanted/sh_wanted_class.lua', 'systems/wanted/sv_wanted_actions.lua')
server.execute('''
    local wanted=bgNPC.Modules.Get('wanted')
    local function target() return {valid=true, IsPlayer=function() return true end, Health=function() return 100 end} end
    local a,b,c=target(),target(),target()
    local w=wanted:AddWanted(a); wanted:AddWanted(b); wanted:AddWanted(c)
    setcv('bgn_wanted_time',180)
    assert(w.wait_time==180 and w.time_reset==now+180,'active wanted timer updates immediately')
    local first=#sent+1
    hook.Run('BGN_PlayerReady',admin)
    local synced=0
    for i=first,#sent do if sent[i][1]=='bgn_module_wanted_UpdateLevel' then synced=synced+1 end end
    assert(synced==3,'late joiner receives every wanted target')
    setcv('bgn_enable_wanted_mode',0)
    assert(#wanted:GetAllWanted()==0,'disabling wanted clears every target, not every other target')
    setcv('bgn_enable_wanted_mode',1)
    local actor={HasTeam=function(_,team) return team=='police' end}
    setcv('bgn_wanted_impunity_limit',0); setcv('bgn_wanted_police_instantly',0)
    hook.Run('BGN_OnKilledActor',actor,a); assert(not wanted:HasWanted(a))
    setcv('bgn_wanted_police_instantly',1)
    hook.Run('BGN_OnKilledActor',actor,a); assert(wanted:HasWanted(a),'police switch works with kill threshold disabled')
    wanted:RemoveWanted(a); setcv('bgn_wanted_police_instantly',0); setcv('bgn_wanted_impunity_limit',2)
    actor.HasTeam=function() return false end
    hook.Run('BGN_OnKilledActor',actor,a); assert(not wanted:HasWanted(a))
    hook.Run('BGN_OnKilledActor',actor,a); assert(wanted:HasWanted(a),'threshold fires on the specified kill')
    local detections=0
    local npc={GetPos=function() return Vector(1000,0,0) end}
    a.GetPos=function() return Vector(0,0,0) end
    local resident={IsAlive=function() return true end, GetNPC=function() return npc end,
        HasState=function() return false end, EqualStateGroup=function() return true end,
        AddEnemy=function() detections=detections+1 end}
    bgNPC.Actors.GetByTeam=function() return {resident} end
    timers.BGN_Timer_CheckingTheWantesStatusOfTargets()
    assert(detections==1,'visible resident at 1000 units detects the target within a 2500-unit radius')
    w=wanted:GetWanted(a); w:LevelDown()
    assert(not wanted:HasWanted(a),'last wanted level can be removed')
''')

load(server, 'core/sh_class.lua', 'nav/sh_astar.lua', 'nav/sh_node_graph.lua', 'nav/sv_nav.lua',
     'nav/providers/sv_graph_provider.lua', 'nav/providers/sv_custom_provider.lua',
     'nav/io/sh_nav_editor.lua', 'nav/legacy/sh_legacy_nodes.lua', 'nav/io/sh_route_dupe.lua')
server.execute('''
    for name,test in pairs(tests) do test(function(ok,msg) assert(ok,name..': '..msg) end) end
    files['citizens_points/gm_test.json']=util.TableToJSON({
        {pos=Vector(0,0,0),parents={2}},{pos=Vector(200,0,0),parents={1}}})
    assert(bgNPC.LegacyNodes.Exists(),'old directory detected')
    files['background_npcs/nodes/gm_test.dat']=util.Compress(util.TableToJSON({version='1.2',nodes={
        {position=Vector(10,0,0),parents={2},links={walk={2}}},
        {position=Vector(210,0,0),parents={1},links={walk={1}}}}}))
    local newest=bgNPC.LegacyNodes.Convert()
    assert(newest:GetPos(1).x==10 and newest:IsLinked(1,2,'walk'),'compressed 1.2 route takes precedence')
    assert(bgNPC.Nav.Load() and bgNPC.Nav.Count()==2,'old directory participates in automatic provider selection')
    local saved=files['background_npcs/graph/gm_test.dat']
    local converted=bgNPC.NodeGraph.Deserialize(saved)
    assert(converted and converted:Count()==2 and converted:IsLinked(1,2,'walk'),'automatic conversion writes the current graph format')
    assert(bgNPC.Nav.GetProvider().source=='file','converted route is a saved graph')
    local legacy=files['background_npcs/nodes/gm_test.dat']
    files['background_npcs/nodes/gm_test.dat']='broken old file'
    assert(bgNPC.Nav.Load() and files['background_npcs/graph/gm_test.dat']==saved,'a valid new graph takes precedence over legacy files')
    files['background_npcs/nodes/gm_test.dat']=legacy
    commands.bgn_save_map(admin)
    local dupe=sent[#sent][3]
    assert(dupe.id=='BGN_NODES' and dupe.map=='gm_test','save produces a route duplication')
    received.bgn_route_dupe_load.f(admin,dupe)
    assert(bgNPC.Nav.GetProvider().source=='dupe' and bgNPC.Nav.Count()==2,'dupe activates navigation')
    assert(files['background_npcs/graph/gm_test.dat']==saved,'loading a dupe does not overwrite saved routes')
    assert(received.bgn_route_dupe_load.opts.admin,'server loading is admin only')
    local active=bgNPC.Nav.GetProvider()
    hooks.CanArmDupe={blocked=function() return false end}
    received.bgn_route_dupe_load.f(admin,dupe)
    assert(bgNPC.Nav.GetProvider()==active,'server enforces duplicator restrictions too')
    local bad={format='bgn_graph',version=2,nodes={0,0,0},links={1,2,1}}
    assert(bgNPC.NodeGraph.FromTable(bad)==nil,'dangling graph link rejected')
    bad.links={}; bad.nodes={0,0,0/0}
    assert(bgNPC.NodeGraph.FromTable(bad)==nil,'non-finite graph position rejected')
    files['background_npcs/graph/gm_test.dat']='broken graph'
    local provider=bgNPC.Nav.CustomProvider()
    assert(provider:Load(),'broken new graph can be recovered from the old directory')
    assert(bgNPC.NodeGraph.Deserialize(files['background_npcs/graph/gm_test.dat']):Count()==2,'recovered graph is saved')
    files['background_npcs/graph/gm_test.dat']=nil
    local write=file.Write
    file.Write=function() end
    local ok,err=provider:Load()
    local active=bgNPC.Nav.GetProvider()
    assert(not bgNPC.Nav.Load(),'navigation reports conversion persistence failure')
    assert(bgNPC.Nav.GetProvider()==active,'failed conversion keeps the previous active provider')
    file.Write=write
    assert(not ok and err:find('could not save graph',1,true),'conversion reports a failed disk write')
''')
server.execute('''
    files={
        ['background_npcs/nodes/gm_alpha.dat']='old',
        ['citizens_points/gm_alpha.json']='old duplicate',
        ['citizens_points/rp_zeta.json']='old',
        ['background_npcs/nodes/gm_bravo.dat']='old',
        ['background_npcs/graph/gm_bravo.dat']='',
        ['background_npcs/nodes/gm_empty.dat']='',
        ['citizens_points/gm_notes.txt']='ignore',
        ['citizens_points/gm_test.json']=util.TableToJSON({version='1.2',nodes={
            {position=Vector(0,0,0),parents={},links={}}}}),
    }
    local maps=bgNPC.LegacyNodes.GetConvertibleMaps()
    assert(table.concat(maps,',')=='gm_alpha,gm_test,rp_zeta','unique sorted maps, no new graphs or empty/other files')
    local command=bgNPC.Commands.list.bgn_convert_legacy_nodes
    local suggestions=command.autocomplete('bgn_convert_legacy_nodes',' gm_')
    assert(#suggestions==2 and suggestions[1]=='bgn_convert_legacy_nodes "gm_alpha"','prefix autocomplete')
    received.bgn_legacy_maps_request.f(admin)
    assert(sent[#sent][1]=='bgn_legacy_maps' and #sent[#sent][3]==3,'server supplies remote map list')
    assert(received.bgn_legacy_maps_request.opts.admin,'map list requests require admin rights')
    command.server(admin,'bgn_convert_legacy_nodes',{})
    assert(files['background_npcs/graph/gm_test.dat'],'no argument converts the current map')
    assert(table.concat(bgNPC.LegacyNodes.GetConvertibleMaps(),',')=='gm_alpha,rp_zeta','converted map disappears')
    assert(#sent[#sent][3]==2,'caller receives updated suggestions after conversion')
''')

load(client, 'core/sh_class.lua', 'nav/sh_node_graph.lua')
client.execute('''
    bgNPC.NavEditor={}
    engine={OpenDupe=function(name) return {data=files[name]} end, WriteDupe=function() return true end}
    render={Capture=function() return 'jpeg' end}
    local ordinary=0
    concommand.Add('dupe_arm',function() ordinary=ordinary+1 end)
    ordinary_dupes=function() return ordinary end
''')
load(client, 'nav/io/sh_route_dupe.lua')
client.execute('''
    hook.Run('InitPostEntity')
    files.regular=util.TableToJSON({Entities={},Constraints={}})
    commands.dupe_arm(admin,'dupe_arm',{'regular'})
    assert(ordinary_dupes()==1,'normal Sandbox duplications still reach the original command')
    files.route=util.TableToJSON({id='BGN_NODES',slibrary=true,data={}})
    admin.IsAdmin=function() return true end
    commands.dupe_arm(admin,'dupe_arm',{'route'})
    assert(sent[#sent][1]=='bgn_route_dupe_load' and ordinary_dupes()==1,'route dupes use the addon channel')
    hooks.CanArmDupe={blocked=function() return false end}
    local count=#sent
    commands.dupe_arm(admin,'dupe_arm',{'route'})
    assert(#sent==count,'server restrictions on arming dupes are respected')
''')
load(client, 'nav/legacy/sh_legacy_nodes.lua')
client.execute('''
    received.bgn_legacy_maps.f(nil,{'gm_remote','rp_remote'})
    local command=bgNPC.Commands.list.bgn_convert_legacy_nodes
    local suggestions=command.autocomplete('bgn_convert_legacy_nodes',' GM_')
    assert(#suggestions==1 and suggestions[1]=='bgn_convert_legacy_nodes "gm_remote"','client uses server maps, case insensitive')
    assert(sent[#sent][1]=='bgn_legacy_maps_request','autocomplete refreshes the list')
    local count=#sent
    command.autocomplete('bgn_convert_legacy_nodes','')
    assert(#sent==count,'typing does not request a new list on every key press')
    received.bgn_legacy_maps.f(nil,{})
    assert(#command.autocomplete('bgn_convert_legacy_nodes','')==0,'updated list removes converted maps')
''')

# Parse every changed/new Lua module with the same LuaJIT language version as GMod.
paths = ['core/sh_cvars.lua', 'systems/wanted/sh_wanted_class.lua', 'systems/wanted/sv_wanted_actions.lua',
         'systems/wanted/cl_wanted_sync.lua', 'nav/sh_node_graph.lua', 'nav/sv_nav.lua',
         'nav/legacy/sh_legacy_nodes.lua', 'nav/io/sh_route_dupe.lua', 'nav/generator/sv_generator.lua',
         'nav/providers/sv_custom_provider.lua',
         'ui/settings/cl_classic_settings.lua']
for path in paths:
    client.execute('assert(loadstring(...))', (ROOT / path).read_text(encoding='utf-8-sig'))
assert (ROOT / 'ui/settings/cl_classic_settings.lua').read_text(encoding='utf-8-sig').count('OpenNewMenuButton(panel)') == 2
print('PASS: client/server CVars, wanted timers/settings/detection, legacy routes, duplications, LuaJIT syntax')
