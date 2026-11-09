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
                # Reproduce the observed engine truncation of wide numeric JSON arrays.
                return [convert(items[i]) for i in range(1, min(len(items), 15000) + 1)]
            return {str(k): convert(x) for k, x in items.items()}
        return json.dumps(convert(value))

    lua.globals().json_encode = to_json
    def from_json(s, ignore_limits=False):
        value = json.loads(s)

        def keys(v):
            if isinstance(v, dict):
                return len(v) + sum(keys(x) for x in v.values())
            if isinstance(v, list):
                return len(v) + sum(keys(x) for x in v)
            return 0

        if not ignore_limits and keys(value) > 15000:
            raise ValueError('engine JSON key limit exceeded')
        return lua.table_from(value, recursive=True)

    lua.globals().json_decode = from_json
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
        util={TableToJSON=json_encode, JSONToTable=function(s,ignore) local ok,v=pcall(json_decode,s,ignore); if ok then return v end end,
            Compress=function(s) return s end, Decompress=function(s) return s end,
            Base64Encode=function(s) return s end, Base64Decode=function(s) return s end,
            TraceLine=function() return {Hit=false} end}
        string.GetExtensionFromFilename=function(s) return s:match('%.([^.]*)$') end
        string.GetPathFromFilename=function(s) return s:match('^(.*[/])') or '' end
        string.Trim=function(s) return s:match('^%s*(.-)%s*$') end
        function table.Copy(value,seen)
            if not istable(value) or isvector(value) then return value end
            seen=seen or {}; if seen[value] then return seen[value] end
            local copy={}; seen[value]=copy
            for k,v in pairs(value) do copy[k]=table.Copy(v,seen) end
            return copy
        end
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
        modules.player_arrest={RemoveTarget=function() end, CanArrest=function() return false end,
            IsProtected=function() return false end}
        modules.team_parent={HasParent=function() return false end}
    ''')
    return lua


def load(lua, *paths):
    for path in paths:
        lua.execute((ROOT / path).read_text(encoding='utf-8-sig'), name=path)


overlay = realm(True)
overlay.execute('''
    function SortedPairs(t)
        local keys={}; for k in pairs(t) do keys[#keys+1]=k end; table.sort(keys)
        local i=0; return function() i=i+1; local k=keys[i]; if k then return k,t[k] end end
    end
    viewers={}; player.GetHumans=function() return viewers end
    bgNPC.cfg.actors={citizen={},police={}}
    bgNPC.Config={IsTypeActive=function() return true end,GetTypeLimit=function() return 10 end}
    bgNPC.Nav={GetName=function() return 'custom' end}
    bgNPC.Points={Count=function() return 123 end}
    bgNPC.ServerLoad={IsLagging=function() return false end}
    bgNPC.Brain={Resolve=function() return 'fsm' end}
    local npc={valid=true,GetPos=function() return Vector(100,0,0) end,GetAngles=function() return {} end,
        OBBMins=function() return Vector(-16,-16,0) end,OBBMaxs=function() return Vector(16,16,72) end,
        Health=function() return 30 end,IsNextBot=function() return false end}
    actor={uid=1,lod=1,GetNPC=function() return npc end,GetPos=npc.GetPos,
        GetType=function() return 'citizen' end,GetState=function() return 'walk' end,IsAlive=function() return true end,
        InVehicle=function() return false end,Health=function() return 30 end}
    bgNPC.Actors.GetAll=function() return {actor} end
''')
load(overlay, 'debug/sv_actor_overlay.lua')
overlay.execute('''
    local tick=timers.BGN_Debug_ActorOverlay
    setcv('bgn_debug',0); tick(); assert(#sent==0, 'debug off sends nothing')
    setcv('bgn_debug',1)
    viewers={{bgn_ready=true,IsAdmin=function() return false end,IsSuperAdmin=function() return false end}}
    tick(); assert(#sent==0, 'ordinary players receive no debug positions')
    admin.bgn_ready=true; viewers[2]=admin
    hooks.BGN_InitActor.BGN_Debug_Spawn(actor)
    now=102; hooks.BGN_RespawnActor.BGN_Debug_Teleport(actor,Vector(200,0,0))
    tick()
    local msg=sent[1]; local row=msg[3][1]
    assert(msg[1]=='bgn.debug_actors' and #msg[2]==1 and msg[2][1]==admin)
    assert(row.uid==1 and row.spawn_age==2 and row.teleport_age==0 and row.teleport_pos.x==200)
    assert(row.pos.x==100 and row.maxs.z==72, 'bounds and positions need no client entity/PVS')
    assert(msg[4].types[1].count==1 and msg[4].types[2].count==0 and msg[4].points==123)
    now=110; tick()
    assert(sent[2][3][1].spawn_pos==nil and sent[2][3][1].teleport_pos==nil, 'event markers expire')
''')

overlay_client = realm(False)
overlay_client.execute('''
    function Color(...) return {...} end
    TEXT_ALIGN_LEFT=0; TEXT_ALIGN_CENTER=1; TEXT_ALIGN_TOP=0
    hook.Remove=function(name,id) if hooks[name] then hooks[name][id]=nil end end
    hook.Add('PostDrawTranslucentRenderables','BGN_Debug_ActorOverlay',function() error('old world pass') end)
    hook.Add('HUDPaint','BGN_Debug_ActorOverlay',function() error('old HUD pass') end)
    cam={Start3D=function() in3d=true end,IgnoreZ=function(value) ignorez=value end,
        End3D=function() assert(not ignorez); in3d=false end}
    render={SetColorMaterial=function() end,DrawWireframeBox=function(...)
        assert(in3d and ignorez, 'bounds must draw over the map in the final HUD pass')
        boxes=boxes+1; assert(select(6,...)==true) end,
        DrawWireframeSphere=function() spheres=spheres+1 end}
    draw={SimpleTextOutlined=function() labels=labels+1 end}
    local mt=getmetatable(Vector())
    function mt:ToScreen() return {visible=true,x=100,y=100} end
    function EyePos() return Vector() end
    function RealFrameTime() return 0.01 end
    boxes=0; spheres=0; labels=0
    setcv('bgn_debug',1)
''')
load(overlay_client, 'debug/cl_actor_overlay.lua')
overlay_client.execute('''
    received['bgn.debug_actors'].f(nil,{{uid=1,type='citizen',pos=Vector(100,0,0),ang={},mins=Vector(),
        maxs=Vector(16,16,72),hp=30,state='walk',body='npc',brain='fsm',lod=1,spawn_age=0,spawn_pos=Vector()}},
        {types={{name='citizen',count=1,limit=10}},nav='custom',points=123,tasks_ms=1,lagging=false})
    assert(not hooks.PostDrawTranslucentRenderables.BGN_Debug_ActorOverlay and not hooks.HUDPaint.BGN_Debug_ActorOverlay,
        'reload must remove old passes')
    local hud=hooks.PostDrawHUD.BGN_Debug_ActorOverlay
    hud(); assert(not in3d and not ignorez, 'restore rendering state')
    assert(boxes==1 and spheres==1 and labels==7, 'bounds, spawn marker, labels and summary render without an entity')
    now=103; hud(); assert(boxes==1, 'stale snapshots must not leave phantom actors')
    now=100; admin.IsAdmin=function() return false end
    hud(); assert(boxes==1, 'ordinary clients must not render debug positions')
    received['bgn.debug_actors'].f(nil,{},{} )
    admin.IsAdmin=function() return true end
    hud(); assert(boxes==1, 'snapshots received without admin rights must be discarded')
    setcv('bgn_debug',0); hud(); assert(boxes==1)
''')

spawn = realm(True)
spawn.execute('''
    setcv('bgn_spawn_radius',3000)
    setcv('bgn_spawn_radius_visibility',2500)
    setcv('bgn_spawn_block_radius',600)
    bgNPC.Vision.PlayerCanSeePos=function(ply) return ply.in_view end
    bgNPC.Util.CanSeeEntity=function(ply) return ply.sees_target end
    function watcher(in_view)
        return {in_view=in_view, GetPos=function() return Vector() end,
            EyePos=function() return Vector(0,0,64) end}
    end
    covered=true; exposed_height=nil; traces=0
    MASK_VISIBLE=1
    util.IsInWorld=function() return true end
    util.TraceLine=function(data)
        assert(data.filter~=nil, 'spawn traces must ignore the player whose eyes they start at')
        traces=traces+1
        return {Hit=covered and data.endpos.z~=exposed_height,StartSolid=trace_start_solid}
    end
''')
# Exercise the actual shared spawn/teleport predicate without the unrelated GLua continue loops.
spawn_source = (ROOT / 'spawner/sv_spawner.lua').read_text(encoding='utf-8-sig')
spawn.execute(spawn_source.split('local function FindSpawnLocationProcess', 1)[0]
              + '\nspawn_allowed = IsNotBlockSpawnPosition')
spawn.execute('''
    local behind,front=watcher(false),watcher(true)
    covered=false
    assert(spawn_allowed(Vector(1000,0,0),{behind}), 'open spots behind the player must allow population')
    assert(traces==0, 'offscreen spots need no cover traces')
    assert(not spawn_allowed(Vector(600,0,0),{behind}), 'block radius still applies behind the player')
    assert(not spawn_allowed(Vector(1000,0,0),{front}), 'exposed spots in view remain blocked')
    assert(not spawn_allowed(Vector(1000,0,0),{behind,front}), 'every player must allow the spot')
    assert(not spawn_allowed(Vector(2800,0,0),{front}), 'distant visible bodies remain blocked')
    covered=true; traces=0
    assert(spawn_allowed(Vector(1000,0,0),{front}) and traces==3,
        'covered front spots inside visibility radius may spawn outside block radius')
    assert(not spawn_allowed(Vector(600,0,0),{front}), 'cover cannot bypass block radius')
    traces=0
    assert(spawn_allowed(Vector(2800,0,0),{front}) and traces==3, 'distant covered bodies may spawn')
    for _,height in ipairs({10,40,64}) do
        exposed_height=height
        assert(not spawn_allowed(Vector(1000,0,0),{front}), 'any exposed body point blocks nearby spawning')
        assert(not spawn_allowed(Vector(2800,0,0),{front}), 'any exposed body point blocks distant spawning')
    end
    exposed_height=nil
    assert(spawn_allowed(Vector(1000,0,0),{behind}), 'initial offscreen search succeeds')
    behind.in_view=true; covered=false
    assert(not spawn_allowed(Vector(1000,0,0),{behind}), 'recheck rejects a player turning toward the spawn')
    behind.in_view=false; behind.sees_target=true
    assert(not spawn_allowed(Vector(1000,0,0),{behind},{valid=true}), 'visible actors must not teleport')
    behind.sees_target=false
    setcv('bgn_spawn_block_radius',1200)
    assert(not spawn_allowed(Vector(1000,0,0),{behind}), 'final checks must read the current block radius')
    setcv('bgn_spawn_block_radius',600)
    assert(spawn_allowed(Vector(1000,0,0),{behind}), 'the current block radius is restored immediately')
    covered=true; trace_start_solid=true
    assert(not spawn_allowed(Vector(1000,0,0),{front}), 'starting inside geometry is not proof of cover')
''')

priority = realm(True)
priority.execute('''
    prioritize=true; rolls=0; budgets=0; views=0; water_checks=0
    bgNPC.Util.Chance=function(percent) assert(percent==50); rolls=rolls+1; return prioritize end
    bgNPC.Tasks.Budget=function() budgets=budgets+1 end
    bgNPC.Vision.PlayerCanSeePos=function(ply,pos) views=views+1; return ply.all or ply.front==pos.y end
    bgNPC.Util.IsVectorInWater=function(pos) water_checks=water_checks+1; return wet or pos.y==1 end
    bgNPC.Util.CanSeeEntity=function() return visible_target end
    util.IsInWorld=function() return true end
    util.TraceLine=function() return {Hit=true} end
    setcv('bgn_spawn_radius_visibility',2500); setcv('bgn_spawn_block_radius',600)
''')
priority.execute(spawn_source.split('local function FindSpawnLocationProcess', 1)[0]
                 + '\nfind_front = FindFrontSpawnPosition')
priority.execute('''
    local function watcher(front)
        return {front=front,GetPos=function() return Vector() end,EyePos=function() return Vector(0,0,64) end}
    end
    local points={}
    for i=1,1000 do
        local pos=Vector(1000,i,0); points[i]={GetPos=function() return pos end}
    end
    local original=points[1]
    local players={watcher(99),watcher(2)}
    assert(find_front(points,players,nil,true)==points[2]:GetPos())
    assert(rolls==1 and budgets==0, 'stop at the first valid position without yielding')
    assert(points[1]==original and #points==1000, 'fallback list remains intact')
    prioritize=false
    local before=views
    local pos,checked=find_front(points,players)
    assert(pos==nil and checked==nil and views==before, 'ordinary searches do no priority work')
    prioritize=true; budgets=0; views=0
    pos,checked=find_front(points,{watcher(33)},nil,true)
    assert(pos==nil and next(checked)==nil and budgets==0 and views==32,
        'priority examines at most 32 points regardless of graph size; other points remain fallbacks')
    local all=watcher(); all.all=true; wet=true; water_checks=0
    pos,checked=find_front(points,{all})
    assert(pos==nil and water_checks==32 and checked[32] and not checked[33],
        'failed priority candidates are marked to avoid repeating expensive validation')
    wet=false; visible_target=true
    pos,checked=find_front({points[2]},{all},{valid=true})
    assert(pos==nil and checked[1], 'priority cannot teleport a visible actor')
    assert(find_front({},players)==nil)
''')

teleport = realm(True)
teleport.execute('''
    bgNPC.Animator={Stop=function() end}
    allowed=true; stuck=false; callbacks=0
    bgNPC.IsHiddenSpawnPosition=function() return allowed end
    bgNPC.NPCIsStuck=function() return stuck end
    timer.Simple=function() error('teleport validation must not defer to another tick') end
    npc={pos=Vector(),GetPos=function(self) return self.pos end,
        SetPos=function(self,pos) self.pos=pos end,PhysWake=function() end}
    actor={IsAlive=function() return true end,GetNPC=function() return npc end,
        CallStateAction=function() end,GetState=function() return 'walk' end,
        GetStateData=function() return {} end,ResetSequence=function() end}
''')
teleport.execute((ROOT / 'spawner/sv_actor_spawner.lua').read_text(encoding='utf-8-sig')
                 .split('local function InitActorsSpawner',1)[0])
teleport.execute('''
    local function done(success) callbacks=callbacks+1; result=success end
    bgNPC:RespawnActor(actor,Vector(1000,0,0),done)
    assert(callbacks==1 and result and npc.pos.x==1000, 'complete the entire teleport before returning')
    allowed=false
    bgNPC:RespawnActor(actor,Vector(2000,0,0),done)
    assert(callbacks==2 and not result and npc.pos.x==1000, 'reject a now-visible destination without moving')
    allowed=true; stuck=true
    bgNPC:RespawnActor(actor,Vector(2000,0,0),done)
    assert(callbacks==3 and not result and npc.pos.x==1000, 'roll back a blocked teleport within the same call')
''')

recycle = realm(True)
recycle.execute('''
    setcv('bgn_actor_unseen_time',30); setcv('bgn_enable',1); setcv('bgn_actors_teleporter',0)
    bgNPC.Tasks.Remove=function() end
    bgNPC.Config={IsTypeActive=function() return true end,GetTypeLimit=function() return 10 end}
    bgNPC.Actors.GetNPCsByType=function() return {npc} end
    bgNPC.Actors.Count=function() return 1 end
    bgNPC.Util.CanSeeEntity=function(ply) return ply.looking and not ply.blocked end
    npc={valid=true}; viewers={{valid=true,looking=false},{valid=true,looking=false}}
    player.GetHumans=function() return viewers end
    actor={mechanics={},data={},GetNPC=function() return npc end,IsAlive=function() return true end,
        InVehicle=function() return in_vehicle end,
        GetData=function(self) return self.data end,
        GetType=function() return 'citizen' end,HasState=function() return busy end,
        Remove=function() removed=removed+1 end}
    bgNPC.Actors.GetAll=function() return {actor} end
    removed=0
''')
# LuaJIT supports goto; translate only GLua's continue in this actor loop for execution outside GMod.
recycle_source = (ROOT / 'spawner/sv_actor_remover.lua').read_text(encoding='utf-8-sig')
recycle_source = recycle_source.split("bgNPC.Tasks.Add('bgn_actors_remover_process'",1)[0]
recycle_source = recycle_source.replace('continue', 'goto next_actor').replace(
    '\n\t\tend\n\tend\nend\n', '\n\t\tend\n\t\t::next_actor::\n\tend\nend\n')
recycle.execute(recycle_source + '\ncan_recycle=CanRecycle; run_recycle=run_remover_process_async')
recycle.execute('''
    hooks.BGN_InitActor.BGN_Recycle_LastSeen(actor)
    assert(not can_recycle(actor,viewers))
    now=129; assert(not can_recycle(actor,viewers))
    now=130; assert(can_recycle(actor,viewers), 'recycle after N unseen seconds regardless of distance')
    viewers[2].looking=true
    assert(not can_recycle(actor,viewers) and actor.__last_player_interaction==130,
        'any player seeing the actor resets the timer at final validation')
    viewers[2].blocked=true
    now=159; assert(not can_recycle(actor,viewers))
    now=160; assert(can_recycle(actor,viewers), 'looking through a wall does not count as seeing')
    local function pass() run_recycle(function() end,function() end,{actor},1) end
    actor.eternal=true; pass(); assert(removed==0)
    actor.eternal=false; in_vehicle=true; pass(); assert(removed==0, 'vehicle occupants have independent lifecycle')
    timers.BGN_Actors_LastSeen(); assert(actor.__last_player_interaction==now)
    in_vehicle=false; actor.__last_player_interaction=130
    actor.eternal=false; actor.state_lock=true; pass(); assert(removed==0)
    actor.state_lock=false; busy=true; pass(); assert(removed==0)
    busy=false
    hooks.BGN_PreRemoveNPC={test=function() return true end}; pass(); assert(removed==0)
    hooks.BGN_PreRemoveNPC={}
    viewers[2].blocked=false; pass(); assert(removed==0, 'fresh visibility prevents removal after timeout')
    viewers[2].looking=false; now=190; pass(); assert(removed==1, 'unseen eligible actors are removed')
    setcv('bgn_actors_teleporter',1)
    bgNPC.Config.GetWantedLevel=function() end
    bgNPC.EnterActorInExistVehicle=function() return false end
    bgNPC.SpawnVehicleWithActor=function() return false end
    bgNPC.FindSpawnPositionAsync=function() return Vector(1000,0,0) end
    bgNPC.IsValidSpawnArea=function() return true end
    bgNPC.IsHiddenSpawnPosition=function() return true end
    actor.RandomState=function() end
    moved=0
    bgNPC.RespawnActor=function(_,_,_,callback) moved=moved+1; callback(true) end
    pass()
    assert(moved==1 and actor.__last_player_interaction==190, 'successful teleport restarts the unseen timer')
    pass(); assert(moved==1, 'freshly teleported actors must not immediately teleport again')
    now=220
    run_recycle(function() viewers[1].looking=true end,function() end,{actor},1)
    assert(moved==1, 'a player who sees the actor after the boundary yield must prevent teleport')
    setcv('bgn_actor_unseen_time',0)
    viewers[1].looking=true; assert(not can_recycle(actor,viewers), 'zero timeout never permits visible removal')
''')

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
    setcv('bgn_wanted_impunity_limit',5); setcv('bgn_wanted_detection_radius',2500)
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

# Exercise GMod's entity-copy callback with a body/brain reference cycle and rebuild actor identity on paste.
server.execute('''
    modifiers={}
    duplicator={RegisterEntityModifier=function(name,f) modifiers[name]=f end}
    bgNPC.Config={GetActor=function(name) if name=='citizen' then return {} end end}
    bgNPC.Actors.Get=function(npc) return npc.BGN_ACTOR_OBJECT end
    local npc={valid=true}
    local actor={npc=npc,info={name='Saved citizen',gender='female'}}
    actor.body={actor=actor}; actor.brain={actor=actor}
    function actor:GetNPC() return self.npc end
    function actor:GetType() return 'citizen' end
    function actor:GetName() return self.info.name end
    function actor:GetGender() return self.info.gender end
    function actor:InVehicle() return false end
    npc.BGN_ACTOR_OBJECT=actor
    npc.EntityMods={other_addon={keep=true}}
    npc.OnEntityCopyTableFinish=function(_,data) data.original_callback=true end
    bgNPC.Actors.GetAll=function() return {actor} end
    saved_npc=npc
    bgNPC.Actor={Create=function(ent,actor_type)
        local a={type=actor_type,info={}}
        function a:SetName(name) self.info.name=name end
        function a:SetGender(gender) self.info.gender=gender end
        ent.BGN_ACTOR_OBJECT=a; return a
    end}
''')
load(server, 'actor/events/sv_save_restore.lua')
server.execute('''
    local data={BGN_ACTOR_OBJECT=saved_npc.BGN_ACTOR_OBJECT,isBgnActor=true,EntityMods=saved_npc.EntityMods}
    assert(not pcall(util.TableToJSON,data),'reproduce the actor body/brain cycle before filtering')
    saved_npc:OnEntityCopyTableFinish(data)
    assert(data.original_callback and data.EntityMods.other_addon.keep,'existing addon copy callback and modifiers preserved')
    assert(not data.isBgnActor and not data.BGN_ACTOR_OBJECT,'runtime actor graph excluded from the save')
    assert(saved_npc.BGN_ACTOR_OBJECT.body.actor==saved_npc.BGN_ACTOR_OBJECT,'saving does not modify the live actor')
    assert(saved_npc.EntityMods.bgn_actor==nil,'copy metadata does not mutate the live entity modifiers')
    local json=util.TableToJSON(data)
    local restored={valid=true}
    modifiers.bgn_actor(nil,restored,util.JSONToTable(json).EntityMods.bgn_actor)
    local actor=restored.BGN_ACTOR_OBJECT
    assert(actor.type=='citizen' and actor.info.name=='Saved citizen' and actor.info.gender=='female','actor identity rebuilt on paste/load')
    modifiers.bgn_actor(nil,{valid=true},{type='missing'})
    local callback=saved_npc.OnEntityCopyTableFinish
    hook.Run('BGN_InitActor',saved_npc.BGN_ACTOR_OBJECT)
    assert(saved_npc.OnEntityCopyTableFinish==callback,'copy hook is not wrapped twice')
''')

# Run the shared command's real client forwarding, server export, client download and generated route pack.
load(server, 'nav/io/sh_compile.lua')
server.execute('''
    files={}
    local graph=bgNPC.NodeGraph(); graph:AddNode(Vector(123,456,0))
    bgNPC.Nav.Load('custom',graph)
    files['background_npcs/graph/gm_test.dat']='stale file'
    files['background_npcs/seats/gm_test.dat']='seats'
    commands.bgn_compile(admin)
    local result=sent[#sent]
    assert(result[1]=='bgn_compile_result' and result[2]==admin and result[5]==2,'server sends route pack to the caller')
    compiled_map,compiled_code,compiled_count=result[3],result[4],result[5]
    assert(files['background_npcs/compile/bgn_compile_gm_test.txt']==compiled_code,'server export retained')
    files={}; assert(loadstring(compiled_code))()
    local copy=bgNPC.NodeGraph.Deserialize(files['background_npcs/graph/gm_test.dat'])
    assert(copy and copy:GetPos(1).x==123,'export uses the active in-memory graph instead of a stale file')
    assert(files['background_npcs/seats/gm_test.dat']=='seats','route pack restores seats too')
''')
client.execute('''
    dialogs={}
    function Derma_Message(text) dialogs[#dialogs+1]=text end
''')
load(client, 'core/sh_commands.lua', 'nav/io/sh_compile.lua')
client.execute('''
    commands.bgn_compile(admin,'bgn_compile',{})
    assert(sent[#sent][1]=='bgn.command' and sent[#sent][2]=='bgn_compile','spawn menu command forwards to server')
''')
client.globals().received['bgn_compile_result']['f'](
    None, server.globals().compiled_map, server.globals().compiled_code, server.globals().compiled_count)
client.execute('''
    assert(files['background_npcs/compile/bgn_compile_gm_test.txt'],'client gets a local copy of the export')
    assert(#dialogs==1 and dialogs[1]:find('garrysmod/data/',1,true),'visible result shows the local output path')
''')
server.execute('''
    notices={}
    bgNPC.Util.Notify=function(_,text,kind) notices[#notices+1]={text,kind} end
    local write=file.Write
    file.Write=function() end
    local count=#sent
    commands.bgn_compile(admin)
    file.Write=write
    assert(#sent==count and #notices==1 and notices[1][2]==NOTIFY_ERROR,'server write failure is visible, no false success')
    files={}; bgNPC.Nav.Load('custom',bgNPC.NodeGraph())
    commands.bgn_compile(admin)
    assert(#notices==2 and notices[2][2]==NOTIFY_ERROR,'nothing to export produces visible feedback')
''')
client.execute('''
    local write=file.Write
    files['background_npcs/compile/bgn_compile_gm_test.txt']=nil
    file.Write=function() end
    local failures=0
    bgNPC.Util.Notify=function(_,_,kind) if kind==NOTIFY_ERROR then failures=failures+1 end end
    received.bgn_compile_result.f(nil,'gm_test','export',1)
    file.Write=write
    assert(failures==1 and #dialogs==1,'client write failure does not show success')
''')

server.execute('''
    local nodes={}
    for i=1,6002 do
        nodes[i]={position=Vector(i+0.125,0,-0.03125),parents={},links={walk={}}}
        if i>1 then nodes[i].parents[1]=i-1; nodes[i].links.walk[1]=i-1 end
    end
    local json=util.TableToJSON({version='1.2',nodes=nodes})
    assert(util.JSONToTable(json)==nil,'fixture exceeds the default JSON reader key limit')
    local graph=bgNPC.LegacyNodes.ToGraph(json)
    assert(graph and graph:Count()==6002 and graph:LinksCount()==6001,'large legacy conversion ignores engine JSON limits')
    bgNPC.Nav.Load('custom',graph)
    commands.bgn_save_map(admin)
    local dupe=sent[#sent][3]
    assert(dupe.encoding=='bgn_graph_base64','route duplication uses an encoded graph instead of wide JSON arrays')
    local copy=bgNPC.NavEditor.GraphFromDupe(util.JSONToTable(util.TableToJSON(dupe),true))
    assert(copy and copy:Count()==6002 and copy:LinksCount()==6001,'large route duplication round trip')
    for i=1,6002 do assert(copy:GetPos(i)==graph:GetPos(i),'duplication coordinates preserved') end
    for i=2,6002 do assert(copy:IsLinked(i-1,i,'walk'),'duplication walk links preserved') end
    received.bgn_nav_editor_save.f(admin,graph:Serialize())
    assert(sent[#sent][1]=='bgn_nav_editor_saved' and sent[#sent][3]==true,'save acknowledged after persistence')
    received.bgn_nav_editor_request.f(admin)
    local reloaded=bgNPC.NodeGraph.Deserialize(sent[#sent][3])
    assert(reloaded and reloaded:Count()==6002 and reloaded:LinksCount()==6001,'large editor save/load preserves counts')
    for i=1,6002 do assert(reloaded:GetPos(i)==graph:GetPos(i),'editor coordinates preserved') end
    for i=2,6002 do assert(reloaded:IsLinked(i-1,i,'walk'),'editor walk links preserved') end
''')

server.execute('''
    files={}; notices={}
    bgNPC.Util.Notify=function(_,text,kind) notices[#notices+1]={text,kind} end
    local vec=getmetatable(Vector())
    function vec.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    function vec.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
    function vec:GetNormalized() local n=self:Distance(Vector()); return Vector(self.x/n,self.y/n,self.z/n) end
    function vec:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
    bgNPC.Tasks.Add=function(id,f) tasks[id]=f end
    bgNPC.Tasks.Remove=function(id) tasks[id]=nil end
    bgNPC.Tasks.Exists=function(id) return tasks[id]~=nil end
    tasks={}
    util.TraceHull=function() return {Hit=false,StartSolid=false} end
''')
load(server, 'nav/generator/sv_generator.lua')
server.execute('''
    local graph=bgNPC.NodeGraph()
    for i=1,4 do graph:AddNode(Vector((i-1)*100,0,0)) end
    graph:RemoveNode(2); graph:Link(1,3,'walk'); graph:Link(3,4,'walk')
    assert(bgNPC.Nav.Load('custom',graph))
    bgNPC.NavGenerator.Start({seeds={}})
    tasks.BGN_NavGenerator(function() end,function() end,function() end)
    assert(graph:Count()==3 and graph:IsLinked(1,3,'walk') and graph:IsLinked(3,4,'walk'),
        'generator simplification must preserve existing corridor points')
    assert(bgNPC.NavGenerator.IsRunning())
    bgNPC.NavGenerator.Stop()
    setcv('bgn_runtime_generator_grid_offset',200); setcv('bgn_nav_generator_max_nodes',6)
    util.PointContents=function() return 0 end; CONTENTS_WATER=1
    util.TraceHull=function(tr)
        if tr.start.x==tr.endpos.x and tr.start.y==tr.endpos.y and tr.start.y==0
            and (tr.start.x==1000 or tr.start.x==1200 or tr.start.x==1400) then
            return {Hit=true,StartSolid=false,HitNormal=Vector(0,0,1),HitPos=Vector(tr.start.x,0,0)}
        end
        return {Hit=false,StartSolid=false}
    end
    local generated=bgNPC.NodeGraph.FromTable(graph:ToTable())
    assert(bgNPC.Nav.Load('custom',generated))
    bgNPC.NavGenerator.Start({seeds={Vector(1000,0,0)}})
    tasks.BGN_NavGenerator(function() end,function() end,function() end)
    assert(generated:Count()==5 and generated:GetPos(2).x==200,'new corridors are simplified while old nodes survive')
    assert(not generated:FindNearest(Vector(1200,0,0),1) and generated:IsLinked(4,6,'walk'),
        'new middle point is merged into a walkable corridor')
    assert(bgNPC.Nav.Load('custom',graph) and not bgNPC.NavGenerator.IsRunning())
    bgNPC.NavGenerator.Start({seeds={}})
    received.bgn_nav_editor_save.f(admin,graph:Serialize())
    assert(not bgNPC.NavGenerator.IsRunning(),'loading a saved graph stops tasks that could overwrite it')
    assert(graph.max_id==4 and graph:Exists(4) and not graph:Exists(2),'save does not invalidate live editor or generator ids')
    local path=bgNPC.Nav.CustomProvider.GraphPath()
    local saved=files[path]
    bgNPC.Nav.GetProvider():GetGraph():AddNode(Vector(999,0,0))
    received.bgn_nav_editor_request.f(admin)
    local loaded=bgNPC.NodeGraph.Deserialize(sent[#sent][3])
    assert(loaded:Count()==3 and loaded:GetPos(3).x==300,'Load points reads disk instead of a mutated active graph')
    assert(bgNPC.Nav.Load('custom',graph))
    received.bgn_nav_editor_request.f(admin)
    assert(bgNPC.NodeGraph.Deserialize(sent[#sent][3]):Count()==3,'unsaved route duplications remain editable')
    local other=bgNPC.Class('OtherProvider',bgNPC.Nav.Provider)
    other.IsAvailable=function() return true end
    bgNPC.Nav.RegisterProvider('other',other); setcv('bgn_nav_provider','other')
    assert(bgNPC.Nav.Load() and bgNPC.Nav.GetName()=='other')
    received.bgn_nav_editor_request.f(admin)
    loaded=bgNPC.NodeGraph.Deserialize(sent[#sent][3])
    assert(loaded:Count()==3,'saved editor points load with another forced navigation provider')
    local active=bgNPC.Nav.GetProvider()
    received.bgn_nav_editor_save.f(admin,'broken')
    assert(files[path]==saved and bgNPC.Nav.GetProvider()==active and notices[#notices][2]==NOTIFY_ERROR,
        'invalid saves keep both the saved route and active provider')
    assert(sent[#sent][1]=='bgn_nav_editor_saved' and sent[#sent][3]==false,'failed saves are acknowledged')
    graph:AddNode(Vector(400,0,0))
    local write=file.Write; file.Write=function() end
    received.bgn_nav_editor_save.f(admin,graph:Serialize())
    assert(files[path]==saved and bgNPC.Nav.GetProvider()==active and notices[#notices][2]==NOTIFY_ERROR,
        'disk write failure never reports success or replaces navigation')
    local chat
    admin.ChatPrint=function(_,text) chat=text end
    files['background_npcs/nodes/gm_test.json']=util.TableToJSON({version='1.2',nodes={
        {position=Vector(1000,0,0),parents={},links={}}}})
    local sent_count=#sent
    commands.bgn_convert_legacy_nodes(admin,'bgn_convert_legacy_nodes',{})
    assert(chat:find('Conversion failed',1,true) and #sent==sent_count and files[path]==saved,
        'explicit conversion reports a failed write and keeps the previous route')
    file.Write=write
    files['background_npcs/nodes/gm_test.json']=nil; files[path]='broken'
    sent_count=#sent
    received.bgn_nav_editor_request.f(admin)
    assert(#sent==sent_count and notices[#notices][2]==NOTIFY_ERROR,'bad saved route produces an error instead of an empty graph')
''')

load(client, 'nav/io/sh_nav_editor.lua')
client.execute('''
    local editor=bgNPC.NavEditor
    local graph=bgNPC.NodeGraph(); graph:AddNode(Vector(1,2,3)); editor.graph=graph
    local loaded=0
    hook.Add('BGN_NavEditorGraphLoaded','regression',function() loaded=loaded+1 end)
    received.bgn_nav_editor_graph.f(nil,'broken')
    assert(editor.graph==graph and loaded==0,'bad downloads preserve client edits and do not fire loaded hooks')
    local count=#sent
    editor.SaveGraph(); editor.RequestGraph(); editor.SaveGraph()
    assert(#sent==count+1 and sent[#sent][1]=='bgn_nav_editor_save','immediate load waits for save completion, duplicate saves are ignored')
    received.bgn_nav_editor_saved.f(nil,true)
    assert(#sent==count+2 and sent[#sent][1]=='bgn_nav_editor_request' and not editor.saving,
        'queued load starts only after successful persistence acknowledgement')
    received.bgn_nav_editor_graph.f(nil,graph:Serialize())
    assert(editor.graph:Count()==1 and loaded==1,'valid download replaces the graph and fires the loaded hook')
    editor.SaveGraph(); editor.RequestGraph(); count=#sent
    received.bgn_nav_editor_saved.f(nil,false)
    assert(#sent==count and not editor.saving and not editor.load_after_save,'failed save keeps edits instead of loading the old route')
''')

# Arrest callbacks must retain the final pose until the fading entity is removed.
arrest = realm(True)
arrest.execute('''
    bgNPC.Actor={InVehicle=function() return false end}; bgNPC.Assert={Arg=function() end}
    bgNPC.Animator={Stop=function() error('arrest released the NPC during fade') end}
    bgNPC.States={Register=function(name,_,state) bgNPC.States[name]=state end}
''')
load(arrest, 'actor/components/sh_animation.lua', 'brain/fsm/states/sv_arrest.lua')
arrest.execute('''
    for _,sequence in ipairs({'arrestcurious','checkmale'}) do
        local component={detention=true,arrest_time=0,holders={}}
        local module=bgNPC.Modules.Get('player_arrest')
        module.GetTarget=function() return component end
        module.CanArrest=function() return true end
        local npc={valid=true}
        function npc:IsPlayer() return false end
        function npc:IsNPC() return false end
        function npc:GetPos() return Vector() end
        function npc:EyeAngles() return {} end
        function npc:EmitSound() end
        function npc:GetActiveWeapon() end
        function npc:LookupSequence(name)
            if name==sequence then return 1 end
            if name=='arrestidle' or name=='checkmalepost' then return 2 end
            return -1
        end
        function npc:SequenceDuration() return 1 end
        local target=setmetatable({npc=npc,mechanics={animator_controller=true}}, {__index=bgNPC.Actor})
        function target:HasState(state) return state=='arrest_surrender' end
        function target:RemoveAllTargets() end
        function target:RemoveAllEnemies() end
        function target:StateLock() end
        target.body={PlaySequence=function() end,
            StopSequence=function() error('arrest body released during fade') end}
        bgNPC.Actors.Get=function(ent) if ent==npc then return target end end
        local police={GetNPC=function() return npc end, GetFirstTarget=function() return npc end,
            TargetsCount=function() return 1 end, Voice=function() end}
        local fades=0
        bgNPC.Util.FadeRemove=function(ent) assert(ent==npc); fades=fades+1 end
        bgNPC.States.arrest.update(police,'arrest',{})
        assert(target:HasSequence(sequence) and fades==0,'arrest animation must precede fading')
        now=now+5
        assert(target:IsSequenceFinished())
        target:ResetSequence()
        local idle=sequence=='arrestcurious' and 'arrestidle' or 'checkmalepost'
        assert(target:HasSequence(idle) and target:IsAnimationPlayed(), 'final arrest pose must survive the callback')
        assert(not target:IsSequenceFinished() and fades==1, 'hold the final pose throughout the fade')
    end
''')

refusal = realm(True)
load(refusal, 'core/sh_cvars.lua', 'systems/wanted/sh_wanted_class.lua', 'systems/arrest/sv_arrest.lua')
refusal.execute('''
    bgNPC.States={Register=function(n,_,v) bgNPC.States[n]=v end}
    setcv('bgn_arrest_mode',1); setcv('bgn_enable_wanted_mode',1)
    suspect={valid=true,alive=true,IsPlayer=function() return true end,Alive=function(self) return self.alive end}
    officer={GetFirstTarget=function(self) return self.target end,
        RemoveAllTargets=function(self) self.target=nil end,AddEnemy=function(self,v) self.enemy=v end,
        GetNPC=function() return {} end,TargetsCount=function() return 1 end,
        SetState=function(self,v) self.state=v end}
''')
load(refusal, 'brain/fsm/states/sv_arrest.lua')
refusal.execute('''
    local arrest=bgNPC.Modules.Get('player_arrest')
    local wanted=bgNPC.Modules.Get('wanted')
    local function attempt(expired)
        arrest:RemoveTarget(suspect)
        arrest:AddTarget(suspect,officer)
        officer.target=suspect; officer.enemy=nil
        arrest:GetTarget(suspect).warningTime=now+(expired and -1 or 10)
        return arrest:GetTarget(suspect)
    end
    officer.RemoveTarget=function() end
    attempt(false)
    assert(bgNPC.States.arrest.pre_start(officer)==nil and not wanted:HasWanted(suspect))
    local component=attempt(true); component.detention=true
    assert(bgNPC.States.arrest.pre_start(officer)==nil and not wanted:HasWanted(suspect),
        'a cooperating player in detention must not become wanted when the warning time expires')
    attempt(true)
    bgNPC.States.arrest.update(officer,'arrest',{})
    assert(officer.state=='defense' and wanted:HasWanted(suspect))
    assert(officer.enemy==suspect and not officer.target)
    local record=wanted:GetWanted(suspect); record:SetLevel(3); local deadline=record.time_reset
    now=now+1; officer.target=suspect
    bgNPC.States.arrest.pre_start(officer)
    assert(wanted:GetWanted(suspect)==record and record.level==3 and record.time_reset==deadline,
        'another officer must not refresh or reset an existing wanted record')
    wanted:RemoveWanted(suspect)
    for _,setting in ipairs({'bgn_enable_wanted_mode','bgn_arrest_mode'}) do
        attempt(true); setcv(setting,0)
        bgNPC.States.arrest.pre_start(officer)
        assert(not wanted:HasWanted(suspect), 'disabled modes must not issue wanted status')
        setcv(setting,1)
    end
    attempt(true); suspect.alive=false
    bgNPC.States.arrest.pre_start(officer); assert(not wanted:HasWanted(suspect))
    suspect.alive=true
    attempt(true); bgNPC.Modes.IsPeaceful=function() return true end
    bgNPC.States.arrest.pre_start(officer); assert(not wanted:HasWanted(suspect))
    bgNPC.Modes.IsPeaceful=function() return false end
    attempt(true); bgNPC.Combat.IsIgnored=function() return true end
    bgNPC.States.arrest.pre_start(officer); assert(not wanted:HasWanted(suspect))
    bgNPC.Combat.IsIgnored=function() return false end
    arrest:RemoveTarget(suspect); officer.target=suspect
    bgNPC.States.arrest.pre_start(officer)
    assert(not wanted:HasWanted(suspect), 'a missing arrest record is not a refusal')
''')

ceasefire = realm(True)
load(ceasefire, 'systems/arrest/sv_arrest.lua')
ceasefire.execute('''
    setcv('bgn_arrest_mode',1)
    list.Set('BGN_Modules','wanted',{HasWanted=function() return false end})
    local module=bgNPC.Modules.Get('player_arrest')
    local player_target={valid=true,IsPlayer=function() return true end}
    local npc_target={valid=true,IsPlayer=function() return false end,IsNPC=function() return true end}
    local target=player_target
    local all={}
    local function Actor(team)
        local a={team=team,state='defense',enemy=target,npc={},alive=true}
        function a:IsAlive() return self.alive end
        function a:HasTeam(t) return self.team==t end
        function a:HasState(s) return self.state==s end
        function a:HasTarget(t) return self.target==t end
        function a:GetFirstTarget() return self.target end
        function a:RemoveTarget(t) if self.target==t then self.target=nil end end
        function a:GetNPC() return self.npc end
        function a:IsStateLock() return self.locked or false end
        function a:StateLock(v) self.locked=v end
        function a:RemoveEnemy(t)
            if self.enemy==t then
                self.enemy=nil
                if not self.locked then self.state='walk' end
            end
        end
        function a:ClearSchedule() self.cleared=true end
        a.body={GetEnemy=function() return a.enemy end}
        function a:GetBody() return self.body end
        all[#all+1]=a
        return a
    end
    local police,citizen,partner,bandit=Actor('police'),Actor('residents'),Actor('police'),Actor('bandits')
    bgNPC.Actors.GetAll=function() return all end
    local suspect
    bgNPC.Actors.Get=function(ent)
        if ent==npc_target then return suspect end
        for _,a in ipairs(all) do if a.npc==ent then return a end end
    end
    bgNPC.Combat.ResolveVehicleAttacker=function(ent) return ent end
    assert(module:AddTarget(target,police))
    assert(not module:IsProtected(target),'an arrest record alone must not create immunity')
    police.state='arrest'; police.target=target
    hook.Run('BGN_SetState',police,'arrest')
    assert(module:IsProtected(target))
    assert(police.state=='arrest' and not police.locked,'clearing the arresting officer must preserve its state')
    assert(not citizen.enemy and citizen.cleared and not partner.enemy and partner.cleared)
    assert(bandit.enemy==target,'hostile factions must not be disarmed by a police arrest')
    assert(hook.Run('BGN_AddActorEnemy',citizen,target)==true,'citizens must not reacquire the suspect')
    assert(hook.Run('BGN_AddActorEnemy',partner,target)==true,'police must not reacquire the suspect')
    assert(hook.Run('BGN_AddActorEnemy',bandit,target)==nil)
    local info={GetAttacker=function() return citizen.npc end}
    assert(hooks.EntityTakeDamage.BGN_ArrestCeaseFire(target,info)==true,'allied bullets already fired must be stopped')
    info.GetAttacker=function() return bandit.npc end
    assert(hooks.EntityTakeDamage.BGN_ArrestCeaseFire(target,info)==nil)
    partner.state='arrest'; partner.target=target
    hook.Run('BGN_SetState',partner,'arrest')
    police.state='walk'
    assert(module:IsProtected(target),'another officer must maintain the ceasefire')
    partner.alive=false
    assert(not module:IsProtected(target),'a dead or absent officer must not leave permanent protection')
    police.state='arrest'
    module:GetTarget(target).warningTime=now-1
    assert(not module:IsProtected(target),'refusal past the warning deadline must end protection')
    module:UpdateArrest(target)
    assert(module:IsProtected(target))
    module:GetTarget(target).surrender=now
    target.bgn_last_attack=now
    assert(not module:IsProtected(target),'attacking after a second surrender chance must end protection')
    module:RemoveTarget(target)
    assert(not module:IsProtected(target),'a completed or cancelled arrest must release protection')

    target=npc_target; suspect=Actor('bandits'); suspect.npc=target
    police.target=target; police.state='arrest'
    assert(module:AddTarget(target,police))
    hook.Run('BGN_SetState',police,'arrest')
    assert(not module:IsProtected(target),'an NPC still fighting must not be protected')
    suspect.state='arrest_surrender'
    hook.Run('BGN_SetState',police,'arrest')
    assert(module:IsProtected(target) and suspect.state=='arrest_surrender')
    suspect.state='defense'
    assert(not module:IsProtected(target),'an NPC resuming combat must end protection')
''')

# Vehicle lifecycle: a stable logical actor replaces its physical body at the seat boundary.
vehicles = realm(True)
vehicles.execute('''
    bgNPC.Actor={}; bgNPC.Assert={Arg=function() end}
    bgNPC.Combat.ResolveVehicleAttacker=function(e) return e end
    bgNPC.Table.FindWhere=function(t,f) for k,v in ipairs(t) do if f(k,v) then return k,v end end return -1 end
    function isbool(v) return type(v)=='boolean' end
    function DamageInfo()
        local d={}
        function d:SetDamage(v) self.amount=v end
        function d:GetDamage() return self.amount end
        function d:SetAttacker(v) self.attacker=v end
        function d:GetAttacker() return self.attacker end
        function d:SetInflictor(v) self.inflictor=v end
        function d:GetInflictor() return self.inflictor end
        return d
    end
    DecentVehicleDestination={}; BGN_VEHICLE={}; bgNPC.Animator={Stop=function() end}
    bgNPC.Table.HasValue=function(t,v) for _,x in ipairs(t) do if x==v then return true end end return false end
    table.HasValue=bgNPC.Table.HasValue
    function Angle(_,y) return {y=y or 0} end
    local vmeta=getmetatable(Vector())
    function vmeta.__mul(v,n) return Vector(v.x*n,v.y*n,v.z*n) end
    function vmeta.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    function vmeta:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
    function vmeta:Cross(b) return Vector(self.y*b.z-self.z*b.y,self.z*b.x-self.x*b.z,self.x*b.y-self.y*b.x) end
    function vmeta:GetNormalized() local n=self:Distance(Vector()); return Vector(self.x/n,self.y/n,self.z/n) end
    util.IsInWorld=function() return true end
    util.TraceHull=function() return {StartSolid=blocked,Hit=blocked} end
    util.TraceLine=function(t) return {Hit=true,StartSolid=exit_start_solid,HitNormal=Vector(0,0,1),HitPos=Vector(t.start.x,t.start.y,exit_floor or 0)} end
    bgNPC.Util.EntityTimer=function(ent,name,_,__,fn) timers[name]=function() fn(ent) end end
    next_uid=0
    function NewEntity(class)
        local e={valid=true,class=class,hp=37,maxhp=73,pos=Vector(),model='original.mdl',clip1=7,clip2=-1}
        function e:GetClass() return self.class end
        function e:IsPlayer() return false end
        function e:IsNPC() return self.class=='npc_citizen' end
        function e:IsNextBot() return false end
        function e:IsVehicle() return false end
        function e:EntIndex() return tostring(self) end
        function e:GetCollisionBounds() return Vector(-16,-16,0),Vector(16,16,72) end
        function e:GetSkin() return 1 end
        function e:GetModelScale() return 1 end
        function e:GetColor() return {} end
        function e:GetMaterial() return '' end
        function e:GetCollisionGroup() return 5 end
        function e:GetBodyGroups() return {} end
        function e:GetKeyValues() return {} end
        function e:SetKeyValue() end
        function e:GetModel() return self.model end
        function e:SetModel(v) self.model=v end
        function e:Health() return self.hp end
        function e:GetMaxHealth() return self.maxhp end
        function e:SetHealth(v) self.hp=v end
        function e:SetMaxHealth(v) self.maxhp=v end
        function e:GetPos() return self.pos end
        function e:SetPos(v) self.pos=v end
        function e:GetAngles() return {y=0} end
        function e:Clip1() return self.clip1 end
        function e:Clip2() return self.clip2 end
        function e:SetClip1(v) self.clip1=v end
        function e:SetClip2(v) self.clip2=v end
        function e:GetActiveWeapon() return self.weapon end
        function e:Remove() self.valid=false; if self.weapon then self.weapon.valid=false end end
        function e:SetNW2Bool() end
        function e:GetNWEntity() return self.seat end
        function e:SetAngles() end
        function e:SetSkin() end
        function e:SetModelScale() end
        function e:SetColor() end
        function e:SetMaterial() end
        function e:SetCollisionGroup() end
        function e:Spawn() end
        function e:Activate() end
        return e
    end
    ents={Create=NewEntity}
    bgNPC.Body={For=function(actor,npc) return {GetEnemy=function() end,GiveWeapon=function(_,class)
        npc.weapon=NewEntity(class); return npc.weapon end} end}
    function NewActor()
        next_uid=next_uid+1
        local npc=NewEntity('npc_citizen'); npc.weapon=NewEntity('weapon_pistol')
        local a=setmetatable({uid=next_uid,npc=npc,mechanics={use_vehicle=true},enemies={},targets={},enemies_always_visible={},info={}}, {__index=bgNPC.Actor})
        function a:GetNPC() return self.npc end
        function a:GetPos() return self.npc:GetPos() end
        function a:GetAngles() return self.npc:GetAngles() end
        function a:GetType() return 'police' end
        function a:GetActiveWeapon() return self.npc.weapon end
        function a:Health() return self.npc:Health() end
        function a:HasTeam(team) return team=='police' end
        function a:HasState(s) return self.state==s end
        function a:EqualStateGroup(g) return g=='calm' and (not self.state or self.state=='walk') end
        function a:GetReactionForDamage() return self.civilian and 'fear' or 'defense' end
        function a:SetReaction(r) self.reaction=r end
        function a:GetLastReaction() return self.reaction end
        function a:RemoveAllTargets() self.targets={} end
        function a:SetState(s) self.state=s end
        function a:EnemiesCount() return #self.enemies end
        function a:IsAlive() return not self.is_removed end
        function a:CreateFakePlayerMethodsForNPC() end
        function a:AddEnemy(e) self.enemies[#self.enemies+1]=e end
        function a:Remove() self.is_removed=true; bgNPC.Actors.UnregisterActor(self) end
        bgNPC.Actors.Register(a)
        return a
    end
    function NewCar()
        local car=NewEntity('car')
        function car:IsVehicle() return true end
        function car:GetModelBounds() return Vector(-100,-50,0),Vector(100,50,80) end
        function car:GetForward() return Vector(1,0,0) end
        function car:GetRight() return Vector(0,1,0) end
        function car:GetUp() return Vector(0,0,1) end
        function car:LocalToWorld(v) return self.pos+v end
        function car:LookupAttachment() return 0 end
        function car:GetAttachment() end
        local p={car=car,passengers={}}
        function p:IsValid() return self.car.valid end
        function p:CanUse() return true end
        function p:GetVehicle() return self.car end
        function p:GetVehicleAI() return self.ai end
        function p:GetDriver() return self.driver end
        function p:GetPassengers() return self.passengers end
        function p:SetDriver(a)
            self.driver=a
            if a then self.ai=NewEntity('npc_decentvehicle'); self.passengers[#self.passengers+1]=a; return true end
            if self.ai then self.ai:Remove() end
            table.remove(self.passengers,1)
        end
        function p:RemovePassenger(a)
            for i,v in ipairs(self.passengers) do if v==a then table.remove(self.passengers,i); return end end
        end
        function p:AddPassenger(a)
            self.passengers[#self.passengers+1]=a
            return true,NewEntity('npc_decentvehicle_passenger')
        end
        BGN_VEHICLE.GetVehicleProvider=function() return p end
        return p
    end
    near_player={valid=true,pos=Vector(),Health=function() return 100 end,Alive=function() return true end,GetPos=function(self) return self.pos end}
    near_player.IsPlayer=function() return true end
    player.GetAll=function() return {near_player} end
''')
load(vehicles, 'api/sh_actors.lua', 'actor/components/sh_vehicle.lua', 'actor/events/sv_self_damage.lua',
     'modules/dv/sv_car_damage_reaction.lua')
vehicles.execute('''
    local p=NewCar(); local a,b=NewActor(),NewActor(); local old=a.npc
    b.enemies={old}; b.targets={old}; b.enemies_always_visible={old}; b.walkTarget=old
    a:EnterVehicle(p.car); b:EnterVehicle(p.car)
    assert(timers.bgn_actor_enter_vehicle_1 and timers.bgn_actor_enter_vehicle_2,'boarding timers are per actor')
    timers.bgn_actor_enter_vehicle_1(); timers.bgn_actor_enter_vehicle_2()
    assert(a:InVehicle() and b:InVehicle() and not old.valid)
    assert(bgNPC.Actors.Count()==2 and bgNPC.Actors.GetByUid(a.uid)==a)
    assert(b.enemies[1]==a.npc and b.targets[1]==a.npc and b.walkTarget==a.npc)
    assert(not old.isBgnActor and not old.BGN_ACTOR_OBJECT,'intentional body removal cannot unregister or kill the actor')
    assert(a.vehicle_body.health==37 and a.vehicle_body.weapons[1].clip1==7)
    blocked=true; assert(not b:ExitVehicle(true) and b:InVehicle(),'blocked exit retains the seat')
    blocked=false; local visual=b.npc
    assert(b:ExitVehicle(true) and b.npc~=visual and b.npc.class=='npc_citizen')
    assert(b.npc.hp==37 and b.npc.weapon.clip1==7 and not b:InVehicle())
    assert(a:ExitVehicle(true) and bgNPC.Actors.GetByUid(a.uid)==a and bgNPC.Actors.Count()==2)
    a:EnterVehicle(p.car); timers.bgn_actor_enter_vehicle_1()
    p.car.valid=false; assert(not a:ExitVehicle(true) and a.is_removed and bgNPC.Actors.Count()==1,
        'vehicle removal never resurrects a physical body')
    p=NewCar(); a=NewActor(); a:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..a.uid]()
    near_player.pos=Vector(800.1,0,0); p.car.maxhp=0; assert(not a:ShouldExitVehicle())
    near_player.pos=Vector(800,0,0); assert(not a:ShouldExitVehicle(), 'neutral observers do not make police dismount')
    a.targets={near_player}; a.state='arrest'
    assert(a:ShouldExitVehicle(), 'police also dismount for a nearby arrest target')
    a.state=nil; a.targets={}
    a.enemies={near_player}; assert(a:ShouldExitVehicle(), 'police dismount for a nearby actual enemy')
    near_player.pos=Vector(5000,0,0); p.car.maxhp=100; p.car.hp=20; assert(a:ShouldExitVehicle())
    p.car.hp=21; assert(not a:ShouldExitVehicle())
    a.enemies={}; near_player.pos=Vector(800,0,0)
    a:TakeVehicleDamage(1,near_player)
    assert(a.enemies[1]==near_player and a:ShouldExitVehicle(), 'actual damage still makes seated police react to their attacker')
    exit_floor=-300
    assert(not a:ExitVehicle(true) and a:InVehicle(), 'do not exit onto a lower road beneath a bridge')
    exit_floor=0
    exit_start_solid=true
    assert(not a:ExitVehicle(true) and a:InVehicle(), 'a ground trace starting inside an object is not a safe floor')
    exit_start_solid=false
    local create=ents.Create
    ents.Create=function(class) local e=create(class); if class=='prop_ragdoll' then corpse=e end; return e end
    local deaths=0
    hook.Add('OnNPCKilled','death_count',function() deaths=deaths+1 end)
    a:TakeVehicleDamage(100,near_player)
    assert(a.is_removed and deaths==1 and corpse, 'a lethal hit creates a corpse and reports one death')
    assert(corpse.model=='original.mdl' and corpse.pos.z==2 and math.abs(corpse.pos.y)==82,
        'the corpse preserves the model and is placed beside the car')
    a:TakeVehicleDamage(100,near_player); assert(deaths==1, 'death is only reported once')
    p=NewCar(); a=NewActor(); a:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..a.uid]()
    blocked=true; corpse=nil; a:TakeVehicleDamage(100,near_player)
    assert(a.is_removed and corpse and corpse.pos==a.npc.pos, 'a blocked exit still leaves a corpse at the seat')
''')

# Exit at the own seat's side, including actors whose collision is disabled.
vehicles.execute('''
    blocked=false
    local p=NewCar(); p.car.pos=Vector(10000,0,0)
    local a,b,c=NewActor(),NewActor(),NewActor()
    for _,actor in ipairs({a,b,c}) do
        actor:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..actor.uid]()
    end
    a.npc.seat=NewEntity('seat'); a.npc.seat.pos=Vector(10040,20,20)
    b.npc.seat=NewEntity('seat'); b.npc.seat.pos=Vector(10040,-20,20)
    c.npc.seat=NewEntity('seat'); c.npc.seat.pos=Vector(10040,-20,20)
    assert(a:ExitVehicle(true) and a.npc.pos==Vector(10040,82,2), 'driver exits next to the driver seat')
    assert(b:ExitVehicle(true) and b.npc.pos==Vector(10040,-82,2), 'passenger exits at its own side')
    assert(c:ExitVehicle(true) and c.npc.pos~=b.npc.pos and c.npc.pos.y<0,
        'a second exit cannot overlap an actor even when the physics trace misses it')
    p=NewCar(); p.car.pos=Vector(20000,0,0); a=NewActor()
    a:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..a.uid]()
    a.npc.seat=NewEntity('seat'); a.npc.seat.pos=Vector(20040,-20,20)
    p.car.Exitpoints={'far_door','own_door'}
    function p.car:LookupAttachment(name) return name end
    function p.car:GetAttachment(name)
        return {Pos=name=='own_door' and Vector(20040,-90,0) or Vector(20040,90,0)}
    end
    assert(a:ExitVehicle(true) and a.npc.pos==Vector(20040,-90,2), 'prefer the nearest model exit attachment')
    p=NewCar(); p.car.pos=Vector(30000,0,0); a=NewActor()
    a:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..a.uid]()
    a.npc.seat=NewEntity('seat'); a.npc.seat.pos=Vector(30020,40,20)
    function a.npc:GetVehicleForward() return Vector(0,1,0) end
    assert(a:ExitVehicle(true) and a.npc.pos==Vector(30132,40,2),
        'side and clearance follow DV vehicle orientation when model forward differs')
    p=NewCar(); p.car.pos=Vector(40000,0,0); a=NewActor()
    a:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..a.uid]()
    a.npc.seat=NewEntity('seat'); a.npc.seat.pos=Vector(40040,-20,20)
    local trace=util.TraceHull
    util.TraceHull=function(t) return {Hit=t.start.y<0,StartSolid=false} end
    assert(a:ExitVehicle(true) and a.npc.pos.y==82, 'use the opposite side when the own side is blocked')
    util.TraceHull=trace
''')

# Actor health forwards to the attached body and safely handles missing methods.
for server_realm in (True, False):
    health = realm(server_realm)
    load(health, 'core/sh_class.lua', 'actor/sh_actor.lua')
    health.execute('''
        local npc={valid=true,Health=function() return 37 end,GetMaxHealth=function() return 73 end}
        local actor=setmetatable({npc=npc},bgNPC.Actor)
        assert(actor:Health()==37 and actor:GetHealth()==37 and actor:GetMaxHealth()==73)
        actor.npc={valid=true,Health=function() return 9 end,GetMaxHealth=function() return 99 end}
        assert(actor:GetHealth()==9 and actor:GetMaxHealth()==99, 'rebinding reads the current NPC or NextBot')
        actor.npc={valid=true,Health=false,GetMaxHealth=123}
        assert(actor:Health()==0 and actor:GetHealth()==0 and actor:GetMaxHealth()==0,
            'missing or non-callable health methods return zero')
        actor.vehicle_body={health=12,max_health=80}
        assert(actor:GetHealth()==12 and actor:GetMaxHealth()==80, 'stored vehicle body supplies missing health methods')
        actor.npc=npc
        assert(actor:GetHealth()==37 and actor:GetMaxHealth()==73, 'valid entity methods take priority over stored values')
        npc.valid=false
        assert(actor:Health()==12 and actor:GetMaxHealth()==80, 'a missing vehicle visual retains stored character health')
        actor.vehicle_body=nil; actor.npc=nil
        assert(actor:GetHealth()==0 and actor:GetMaxHealth()==0, 'an absent body returns zero')
    ''')

# Medics read both their own and their partner's health through the actor API.
medics = realm(True)
load(medics, 'core/sh_class.lua', 'actor/sh_actor.lua', 'systems/sv_medics.lua')
medics.execute('''
    local npc={valid=true,Health=function() return 100 end,GetMaxHealth=function() return 100 end}
    local partner=setmetatable({npc=npc,IsAlive=function() return true end,InVehicle=function() return false end,
        HasState=function() return false end,SetState=function(self,s) self.state=s end},bgNPC.Actor)
    local actor=setmetatable({npc=npc,GetType=function() return 'medic' end,medic_partner=partner},bgNPC.Actor)
    actor.medic_call={medic=actor}
    bgNPC.Actors.Get=function() return actor end
    local attacker={IsPlayer=function() return true end}
    hooks.BGN_PreReactionTakeDamage.BGN_Medics_Attacker(attacker,npc)
    assert(partner.state=='brawl', 'a healthy partner protects the medic performing a revival')
    partner.state=nil; partner.Health=function() return 20 end
    hooks.BGN_PreReactionTakeDamage.BGN_Medics_Attacker(attacker,npc)
    assert(partner.state==nil, 'a wounded partner must not be sent to fight')
''')

# Run the actual entry point with the real directory order and module registration.
startup = realm(True)
startup.execute('''
    resource={AddWorkshop=function() end}; AddCSLuaFile=function() end
    bgNPC.Config={SaveDefaults=function() end}
    list.Set('', 'wanted', {AddWanted=function() wanted_added=true end})
    list.Set('', 'player_arrest', nil)
''')
def startup_find(pattern, _realm):
    folder = ROOT / pattern.removeprefix('background_npcs_core/').removesuffix('/*')
    if not folder.is_dir():
        return startup.table(), startup.table()
    return (startup.table_from(sorted(p.name for p in folder.iterdir() if p.is_file())),
            startup.table_from(sorted(p.name for p in folder.iterdir() if p.is_dir())))

def startup_include(path):
    path = path.removeprefix('background_npcs_core/')
    if path in ('systems/arrest/sv_arrest.lua', 'systems/sv_offender.lua'):
        if path == 'systems/sv_offender.lua':
            startup.execute("assert(bgNPC.Modules.Get('player_arrest'), 'arrest must register before offender captures the module')")
        load(startup, path)

startup.globals().file.Find = startup_find
startup.globals().include = startup_include
load(startup, 'sh_init.lua')
startup.execute('''
    local npc={valid=true,GetPos=function() return Vector() end}
    local actor={data={team={'residents'}},IsAlive=function() return true end,IsCivilian=function() return true end,
        GetNPC=function() return npc end,SetTeam=function(self,t) self.team=t end}
    local victim={GetNPC=function() end,HasTeam=function() return true end}
    bgNPC.Actors.Get=function() return actor end
    bgNPC.Actors.GetInRadius=function() return {} end
    hooks.BGN_OnKilledActor.BGN_Offender(victim,npc)
    assert(actor.team[1]=='offenders' and wanted_added, 'witnessed civilian murder registers an offender without a missing module')
''')

# Vehicle hits use the same reactions and witness hook as hits on foot.
vehicle_vision = realm(True)
vehicle_vision.execute('''
    ENT={}; bgNPC.Assert={Arg=function() end}
    local vec=getmetatable(Vector())
    function vec.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    function vec:Length() return math.sqrt(self.x^2+self.y^2+self.z^2) end
    function vec:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
    car={valid=true}; target_car={valid=true}; wall={valid=true}
    watcher={valid=true,vehicle_provider={GetVehicleAI=function() return driver end},
        GetForward=function() return Vector(1,0,0) end,
        EyePos=function() return Vector() end, Health=function() return 100 end}
    driver={valid=true,GetVehicleForward=function() return Vector(0,1,0) end}
    target={valid=true,Health=function() return 100 end,
        OBBCenter=function() return Vector() end, LocalToWorld=function() return Vector(0,100,0) end,
        WorldSpaceCenter=function() return Vector(0,100,0) end}
    bgNPC.Actors.Get=function(e)
        if e==watcher then return {GetVehicle=function() return car end} end
        if e==target then return {GetVehicle=function() return target_car end} end
    end
    util.TraceLine=function(data)
        assert(data.filter[1]==watcher and data.filter[2]==car, 'the own chassis must not hide a seated witness')
        return {Hit=true,Entity=hit or target}
    end
''')
load(vehicle_vision, '../entities/npc_decentvehicle_passenger/shared.lua', 'core/sh_util.lua', 'api/sh_vision.lua')
vehicle_vision.execute('''
    watcher.GetVehicleForward=ENT.GetVehicleForward
    -- The method used by DV's playermeta.lua on passengers.
    function watcher:GetAimVector() return self:GetVehicleForward() end
    assert(watcher:GetAimVector()==Vector(0,1,0), 'passenger view uses the driver vehicle orientation')
    assert(bgNPC.Util.CanSeeEntity(watcher,target,true))
    assert(bgNPC.Vision.HasLineOfSight(watcher,target))
    hit=target_car
    assert(bgNPC.Util.CanSeeEntity(watcher,target,true) and bgNPC.Vision.HasLineOfSight(watcher,target),
        'seeing a victim chassis counts as seeing its occupant')
    hit=wall; wall.IsVehicle=function() return false end
    assert(not bgNPC.Util.CanSeeEntity(watcher,target,true) and not bgNPC.Vision.HasLineOfSight(watcher,target),
        'walls still block seated witnesses')
    driver.valid=false
    assert(watcher:GetAimVector()==Vector(1,0,0), 'passenger view survives driver removal')
''')

witness_source = (ROOT / 'actor/events/sv_damage_reaction.lua').read_text(encoding='utf-8-sig')
witness_source = witness_source.replace('local actor = actors[i]', 'do local actor = actors[i]')
witness_source = witness_source.replace('continue', 'goto next_witness').replace(
    "\n\tend\nend)", "\n\tend ::next_witness::\n\tend\nend)")
vehicles.execute(witness_source)
vehicles.execute('''
    blocked=false
    list.Set('', 'wanted', {HasWanted=function() return false end})
    bgNPC.Combat.ResolveEnemy=function(_,target,attacker) return attacker end
    local p=NewCar(); local victim=NewActor(); local witness=NewActor()
    victim.civilian=true
    function victim:HasTeam() return false end
    function witness:GetReactionForProtect() return 'defense' end
    bgNPC.Actors.GetInRadius=function() return {witness} end
    victim:EnterVehicle(p.car); timers['bgn_actor_enter_vehicle_'..victim.uid]()
    local wcar=NewCar()
    witness:EnterVehicle(wcar.car); timers['bgn_actor_enter_vehicle_'..witness.uid]()
    local hit=DamageInfo(); hit:SetDamage(10); hit:SetAttacker(near_player); hit:SetInflictor(near_player)
    bgNPC.DVCars={p}
    hook.Run('EntityTakeDamage',p.car,hit)
    assert(victim.state=='fear' and victim.enemies[1]==near_player, 'seated civilians remember the attacker')
    assert(witness.state=='defense' and witness.enemies[1]==near_player, 'seated police witness an attack on another car')
    if victim:InVehicle() then assert(victim:ExitVehicle(true)) end
    assert(victim.enemies[1]==near_player and victim.state=='fear',
        'exit retains the reaction and attacker')
    bgNPC.Actors.GetInRadius=function() return {} end
    local seated=witness.npc; local hp=witness:Health()
    assert(hook.Run('EntityTakeDamage',seated,hit)==true)
    assert(witness:Health()==hp-10, 'direct occupant hits apply damage exactly once')
    hooks.BGN_PreReactionTakeDamage={block=function() return true end}
    witness:TakeVehicleDamage(10,near_player)
    assert(witness:Health()==hp-10, 'damage cancellation is respected in a seat')
    hooks.BGN_PreReactionTakeDamage=nil
    witness:TakeVehicleDamage(0,near_player)
    assert(witness:Health()==hp-10, 'zero damage is ignored')
''')

# Run the actual traffic task and attached Think with a stationary car.
traffic = realm(True)
traffic.execute('''
    local vec=getmetatable(Vector())
    function vec.__mul(v,n) return Vector(v.x*n,v.y*n,v.z*n) end
    function vec:LengthSqr() return self:DistToSqr(Vector()) end
    function vec:GetNormalized() local n=math.sqrt(self:LengthSqr()); return Vector(self.x/n,self.y/n,self.z/n) end
    function vec:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
    function vec.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    math.Rand=function(a,b) return (a+b)/2 end
    bgNPC.Tasks={Add=function(_,fn) traffic_task=fn end}
    car={valid=true,isBgnVehicle=true,pos=Vector(),velocity=Vector(),
        WorldSpaceCenter=function(self) return self.pos end,
        GetPos=function(self) return self.pos end,GetVelocity=function(self) return self.velocity end}
    ai={valid=true,v=car,WaitUntilNext=0,Emergency=0,Preference={StopAtTL=true},Waypoint={Target=Vector(500,0,0)},Trace={Hit=false},
        GetVehicleForward=function() return Vector(1,0,0) end,
        Think=function() end,DoTrace=function() end,IsValidVehicle=function() return true end,
        GetMaxSteeringAngle=function() return 30 end,AtTrafficLight=function(self) return self.red end,
        SetHorn=function(self,on) self.horn=on; if on then self.honks=(self.honks or 0)+1 end end}
    bgNPC.DVCars={{GetVehicle=function() return car end,GetVehicleAI=function() return ai end}}
    function ErrorNoHalt(err) error(err) end
''')
load(traffic, 'modules/dv/sv_vehicle_traffic.lua')
traffic.execute('''
    local trace=ai.DoTrace
    bgNPC.VehicleTraffic.Attach(ai)
    assert(ai.DoTrace==trace, 'keep DV trace cadence: its clear-road permission expires after 0.1 seconds')
    local task=coroutine.create(traffic_task)
    local function step(t)
        now=t
        local ok,err=coroutine.resume(task,function() end,coroutine.yield,function() end)
        assert(ok,err)
        ai:Think()
    end
    step(100); step(103); assert(not ai.horn, 'standing on an empty road is not a reason to honk')
    ai.Trace={Hit=true,HitWorld=true,Entity={valid=true}}
    step(103.1); assert(not ai.horn, 'do not honk at world geometry')
    ai.Trace={Hit=true,Entity={valid=true}}; car.velocity=Vector(30,0,0)
    step(103.2); assert(not ai.horn, 'normal movement must not trigger the stuck horn')
    car.velocity=Vector(); step(106.3)
    assert(ai.horn and ai.honks==1, 'a stalled car may ask a real blocker to move')
    ai.bgnTraffic.nextPlan=200
    now=106.46; ai:Think(); assert(not ai.horn, 'a honk is a short pulse')
    step(107); assert(ai.honks==1, 'do not repeat honks every traffic update')
    step(109.4); assert(ai.honks==1, 'the old three-second cycle must not repeat')
    ai.red=true; step(110); assert(not ai.horn, 'a red light cancels the horn')
    ai.red=false; ai.WaitForCaller=true; step(111); assert(not ai.horn)
    ai.WaitForCaller=false; ai.WaitUntilNext=113; step(112); assert(not ai.horn)
    ai.WaitUntilNext=0
    -- Suppress path planning while advancing the cooldown clock.
    ai.bgnTraffic.nextPlan=200
    step(117.31); assert(ai.horn and ai.honks==2, 'a persistent blocker may be reminded after the longer pause')
    ai.bgnTraffic.mode='planning'; ai.Trace={Hit=false}; ai:Think()
    assert(not ai.bgnTraffic.mode, 'a cleared road immediately returns control to DV')
    ai.bgnTraffic.geometry={ride=20}
    local from={Target=Vector(100,100,-20),Neighbors={2}}
    local to={Target=Vector(-200,100,-20),Neighbors={}}
    DecentVehicleDestination={Waypoints={from,to,
        {Target=Vector(100,200,-20),Neighbors={4}}, {Target=Vector(300,200,-20),Neighbors={}},
        {Target=Vector(100,100,100),Neighbors={6}}, {Target=Vector(-200,100,100),Neighbors={}}},
        WaypointAvailable=function() return true end}
    local lanes=bgNPC.VehicleTraffic.AlternateLanes(ai)
    assert(#lanes==1 and lanes[1].from==from and lanes[1].to==to,
        'fallback selects another direction on the same road level, not the current lane or bridge')
    ai.bgnTraffic.rejectedLanes={[to]=now+30}
    assert(#bgNPC.VehicleTraffic.AlternateLanes(ai)==0, 'do not immediately retry a lane whose maneuver failed')
    ai.bgnTraffic.rejectedLanes[to]=now-1
    assert(#bgNPC.VehicleTraffic.AlternateLanes(ai)==1, 'a failed lane can be retried after its cooldown')
    DecentVehicleDestination.WaypointAvailable=function() return false end
    assert(#bgNPC.VehicleTraffic.AlternateLanes(ai)==0, 'lane changes respect DV waypoint access')
    math.Clamp=function(v,a,b) return math.max(a,math.min(b,v)) end
    ai.GetVehicleRight=function() return Vector(0,-1,0) end
    ai.SetSteering=function(self,v) self.steering=v end
    ai.SetThrottle=function(self,v) self.throttle=v end
    ai.SetHandbrake=function() end
    ai.DoLights=function() end; ai.SetDriverPosition=function() end; ai.NextThink=function() end
    now=150; ai.Trace={Hit=true}
    ai.bgnTraffic={mode='maneuver',path={{pos=Vector(50,-100,0),dir=-1}},index=1,
        geometry={wheelbase=100},nextSafety=200}
    ai:Think()
    assert(ai.steering>0 and ai.throttle<0, 'reverse pure pursuit keeps curvature and reverses travel direction')
    ai.bgnTraffic.path[1].dir=1; ai:Think()
    assert(ai.steering>0 and ai.throttle>0, 'forward pursuit retains the normal steering sign')
    ai.StopDriving=function(self) self.throttle=0 end
    ai.bgnTraffic.mode='planning'; ai.Trace={Hit=false}; ai.TraceWaypoint={Hit=true}
    ai:Think()
    assert(ai.bgnTraffic.mode=='planning', 'a blocked waypoint trace still requires recovery when the forward trace is clear')
    ai.TraceWaypoint.Hit=false; ai:Think()
    assert(not ai.bgnTraffic.mode, 'release control only after both native DV traces clear')
    ai.bgnTraffic={mode='maneuver',lane={},path={{pos=Vector(50,-100,0),dir=1}},index=1}
    car.pos=Vector(90,-100,0); ai:Think()
    assert(ai.bgnTraffic.index==2, 'a passed nearby path point must not make the car circle back')
    local lane={}
    ai.bgnTraffic={mode='maneuver',lane=lane,index=1,
        path={{pos=car.pos,dir=-1},{pos=Vector(200,-100,0),dir=1}}}
    car.velocity=Vector(20,0,0); ai:Think()
    assert(ai.bgnTraffic.mode=='maneuver' and not ai.bgnTraffic.retryLane, 'brake before changing travel direction')
    car.velocity=Vector(); ai:Think()
    assert(ai.bgnTraffic.retryLane==lane and not ai.bgnTraffic.mode, 'replan a cusp from the stopped physical pose')
    ai:Think(); assert(ai.throttle==0, 'hold the brake while the traffic task prepares the new plan')
''')

returning = realm(True)
return_source = (ROOT / 'modules/dv/sv_return_to_vehicle.lua').read_text(encoding='utf-8-sig')
returning.execute(return_source.split("timer.Create('BGN_ReturnToVehicle'", 1)[0] + '\nNearForReturn=IsAnyoneNear')
returning.execute('''
    local bystander={valid=true,Alive=function() return true end,GetPos=function() return Vector() end}
    player.GetAll=function() return {bystander} end
    local a={enemies={},HasTeam=function() return true end}
    assert(not NearForReturn(a,Vector()), 'a neutral nearby observer does not strand police on foot')
    a.enemies={bystander}; assert(NearForReturn(a,Vector()), 'an actual nearby enemy delays return')
    a.enemies={}; a.HasTeam=function() return false end
    assert(NearForReturn(a,Vector()), 'civilian return keeps its player-distance rule')
''')

rendering = realm(False)
rendering.execute('''
    setcv('bgn_cl_field_view_optimization',1)
    function tobool(v) return tonumber(v)~=0 end
    function RenderNPC(in_car,owned)
        local n={valid=true,hidden=true,bgn_render_optimization=owned}
        function n:Health() return 100 end
        function n:GetNW2Bool() return in_car end
        function n:SetNoDraw(v) self.hidden=v end
        n.bgn_hidden_weapon={valid=true,hidden=true,SetNoDraw=n.SetNoDraw}
        return n
    end
    seated=RenderNPC(true,true); culled=RenderNPC(false,true); other=RenderNPC(false,false)
    seated_weapon=seated.bgn_hidden_weapon; culled_weapon=culled.bgn_hidden_weapon
    bgNPC.Actors.GetAllNPCs=function() return {seated,culled,other} end
''')
# Only the settings callback is needed here; the task below uses GMod's continue.
render_source = (ROOT / 'systems/cl_render_optimization.lua').read_text(encoding='utf-8-sig')
rendering.execute(render_source.split('bgNPC.Tasks.Add', 1)[0])
rendering.execute('''
    setcv('bgn_cl_field_view_optimization',0)
    assert(seated.hidden and seated_weapon.hidden,'disabling culling must not reveal actors or weapons inside cars')
    assert(not culled.hidden and not culled_weapon.hidden,'disabling culling must restore both NPC and weapon')
    assert(other.hidden,'culling must not clear hiding owned by another system')
''')

speech = realm(False)
speech.execute('''
    bgNPC.cfg.replics={conv_greet={'hello','reply'},police_arrest_order={'down'}}
    bgNPC.cfg.replics_language='english'
    played={}
    local npc={valid=true,EmitSound=function(self,path,level,pitch,volume,channel)
        assert(channel==CHAN_VOICE and level==70 and pitch==100 and volume==1)
        played[#played+1]=path
    end}
    speaker={GetNPC=function() return npc end,HasTeam=function() return false end,
        GetGenderByModel=function() return 'female' end}
    CHAN_VOICE=2
    bgNPC.Actors.GetByUid=function() return speaker end
''')
load(speech, 'actor/cl_actor_voice.lua')
speech.execute('''
    local clip='background_npcs/vo/english/conv_greet/1_f.ogg'
    files['sound/'..clip]='audio'
    for _,value in ipairs({1,2}) do
        setcv('bgn_cl_voices',value)
        assert(bgNPC.VoicePlay(speaker,'conv_greet',1))
        assert(played[#played]==clip,'both current and saved classic settings must play our conversation clip')
    end
    assert(not bgNPC.VoicePlay(speaker,'conv_greet',2),'missing conversation clips must not substitute unrelated HL2 speech')
    received.bgn_actor_voice.f(nil,1,'police_arrest_order','npc/metropolice/vo/getdown.wav')
    assert(played[3]=='npc/metropolice/vo/getdown.wav','individual events retain their configured fallback')
    setcv('bgn_cl_voices',0)
    assert(not bgNPC.VoicePlay(speaker,'conv_greet',1) and #played==3,'muting must still work')
''')
sync = realm(False)
sync.execute('''
    bgNPC.Assert={Arg=function() end}
    bgNPC.Table.HasValue=function(t,v) for _,x in ipairs(t) do if x==v then return true end end return false end
    function SyncEntity() return {valid=true,EntIndex=function(self) return tostring(self) end} end
    bgNPC.Actor={Create=function(npc,kind,uid)
        local a={uid=uid,npc=npc,kind=kind,mechanics={},enemies={},targets={},enemies_always_visible={},
            GetNPC=function(self) return self.npc end,GetType=function(self) return self.kind end,
            SetName=function() end,SetGender=function() end,SyncState=function(self,v) self.state=v end}
        return a
    end}
''')
load(sync, 'api/sh_actors.lua', 'actor/sync/cl_sync.lua')
sync.execute('''
    assert(received.bgn_actor_sync_data.opts.wait_entities)
    local first,second=SyncEntity(),SyncEntity()
    received.bgn_actor_sync_data.f(nil,17,{npc=first,actor_type='police',state='walk',entity_generation=0})
    local a=bgNPC.Actors.GetByUid(17)
    assert(a and a.kind=='police' and a.state=='walk','state sync recovers missed registration')
    received.bgn_actor_sync_data.f(nil,17,{npc=second,actor_type='police',state='walk',entity_generation=1})
    assert(bgNPC.Actors.GetByUid(17)==a and a.npc==second and bgNPC.Actors.Count()==1,'rebind retains identity without duplicate population')
    received.bgn_add_actor_from_client.f(nil,first,'police',17,nil,0)
    assert(a.npc==second,'late initial packet cannot revive the deleted body')
    second.valid=false; bgNPC.Actors.ClearRemoved()
    assert(bgNPC.Actors.GetByUid(17)==a,'a missing client body does not retire the server-owned identity')
    local third=SyncEntity()
    received.bgn_actor_sync_data.f(nil,17,{npc=third,actor_type='police',state='walk',entity_generation=2})
    assert(bgNPC.Actors.GetByUid(17)==a and a.npc==third,'identity survives a gap between entity packets')
    received.bgm_update_death_actors_on_client.f(nil,second,17)
    received.bgn_actor_sync_data.f(nil,17,{npc=second,actor_type='police',entity_generation=1})
    assert(not bgNPC.Actors.GetByUid(17),'late state sync cannot resurrect a removed actor')
''')

medics = realm(True)
medics.execute('''
    function table.Empty(t) for k in pairs(t) do t[k]=nil end end
    setcv('bgn_medic_danger_time',60); setcv('bgn_medic_danger_radius',1500)
    bgNPC.Config={IsTypeActive=function() return true end,GetTypeLimit=function() return 0 end}
    bgNPC.Combat.ResolveVehicleAttacker=function(ent) return ent end
    function Person(pos)
        return {valid=true,pos=pos or Vector(),hp=100,Health=function(self) return self.hp end,
            GetPos=function(self) return self.pos end,GetModel=function() return 'model' end,
            GetSkin=function() return 0 end}
    end
    function Actor(npc,kind)
        return {GetNPC=function() return npc end,GetType=function() return kind or 'medic' end,
            InVehicle=function() return false end,IsAlive=function() return npc.hp>0 end,
            EqualStateGroup=function() return false end,GetPos=function() return npc.pos end,
            StopWalk=function(self) self.stopped=true end,
            GetBody=function(self) return {StopMoving=function() self.body_stopped=true end} end}
    end
    killer=Person(); second_killer=Person()
    victim=Actor(Person()); other_victim=Actor(Person(Vector(4000,0,0)))
    find_requests=0; free_medics={}
    bgNPC.Actors.GetByType=function() find_requests=find_requests+1; return free_medics end
    bgNPC.Actors.GetNPCsByType=function() return {} end
    bgNPC.Actors.Count=function() return 0 end
    bgNPC.States={Register=function(n,_,v) bgNPC.States[n]=v end}
''')
load(medics, 'systems/sv_medics.lua', 'brain/fsm/states/sv_medic_revive.lua')
medics.execute('''
    local m=bgNPC.Medics
    local death=hooks.BGN_OnKilledActor.BGN_Medics_Call
    death(victim,killer)
    assert(m.IsBlocked(Vector()) and m.IsBlocked(Vector(1500,0,0)))
    assert(not m.IsBlocked(Vector(1501,0,0)))
    local spawn=hooks.BGN_OnValidSpawnActor.BGN_Medics_DangerArea
    assert(spawn('medic',nil,nil,Vector())==true)
    assert(spawn('citizen',nil,nil,Vector())==nil)
    assert(spawn('medic',nil,nil,Vector(1501,0,0))==nil)
    local call=m.calls[1]
    local responder,partner=Actor(Person()),Actor(Person())
    call.medic=responder; call.partner=partner
    responder.medic_call=call; partner.medic_call=call
    responder.drive_target_pos=call.pos; partner.drive_target_pos=call.pos
    timers.BGN_MedicsDispatch()
    assert(not call.medic and not call.partner and not call.closed and find_requests==0)
    for _,a in ipairs({responder,partner}) do
        assert(not a.medic_call and not a.drive_target_pos and a.stopped and a.body_stopped)
    end
    call.ragdoll={valid=true,Remove=function() error('blocked revival must preserve the body') end}
    m.Revive(call)
    responder.state_data={call=call,give_up=now+40,revive_end=now-1}
    responder.GetStateData=function(self) return self.state_data end
    responder.StopStaticSequence=function(self) self.animation_stopped=true end
    responder.RandomState=function(self) self.left=true end
    call.medic=responder
    bgNPC.States.medic_revive.update(responder)
    assert(responder.animation_stopped and responder.left and not call.done,
        'a medic must abandon revival immediately, before the dispatch timer catches up')
    call.medic=nil
    now=159.99; assert(m.IsBlocked(Vector()))
    now=160; assert(not m.IsBlocked(Vector()), 'time alone must lift the restriction')
    free_medics={responder}; timers.BGN_MedicsDispatch()
    assert(call.medic==responder, 'a pending call must become available again')

    death(victim,killer); death(other_victim,second_killer)
    hooks.PlayerDeath.BGN_Medics_ClearDanger(killer)
    assert(not m.IsBlocked(Vector()), 'death event must release a player even if already respawned')
    assert(m.IsBlocked(Vector(4000,0,0)), 'another killer must keep its own restriction')
    hooks.BGN_OnKilledActor.BGN_Medics_Call(Actor(second_killer,'gangster'),killer)
    assert(not m.IsBlocked(Vector(4000,0,0)), 'actor/NextBot death must release its restriction')
    death(victim,killer); hooks.OnNPCKilled.BGN_Medics_ClearDanger(killer)
    assert(not m.IsBlocked(Vector()), 'ordinary NPC death must also lift the restriction')
    death(victim,killer); death(victim,second_killer)
    hooks.PlayerDeath.BGN_Medics_ClearDanger(killer)
    assert(m.IsBlocked(Vector()), 'overlapping areas from other killers remain blocked')
    hooks.PostCleanupMap.BGN_Medics_ClearCalls()
    assert(not m.IsBlocked(Vector()) and #m.calls==0)
    victim.InVehicle=function() return true end
    death(victim,killer)
    assert(m.IsBlocked(Vector()) and #m.calls==0, 'medics killed in cars must also create a danger area')
    hooks.PostCleanupMap.BGN_Medics_ClearCalls()
    setcv('bgn_medic_danger_time',0); death(victim,killer)
    setcv('bgn_medic_danger_time',60)
    assert(not m.IsBlocked(Vector()), 'disabled restriction must not accumulate new areas')
''')
# Isolate the vehicle spawn entry point; the unrelated boarding loop uses GMod's continue.
vehicle_spawn_source = (ROOT / 'spawner/sv_dv_spawner.lua').read_text(encoding='utf-8-sig')
medics.execute('function bgNPC:SpawnVehicleWithActor' + vehicle_spawn_source.split(
    'function bgNPC:SpawnVehicleWithActor', 1)[1])
medics.execute('''
    setcv('bgn_enable_dv_support',1)
    DecentVehicleDestination={Waypoints={{}}}
    player.GetCount=function() return 1 end
    player.GetAll=function() return {killer} end
    bgNPC.Table.Random=function(t) return t[1] end
    function Angle() return {} end
    FindSpawnLocation=function() return {pos=Vector(),ang={}} end
    local medic=Actor(Person())
    medic.GetData=function() return {vehicles={'ambulance'}} end
    local spawned=0
    bgNPC.SpawnVehicle=function() spawned=spawned+1 end
    hooks.BGN_OnKilledActor.BGN_Medics_Call(victim,killer)
    assert(bgNPC:SpawnVehicleWithActor(medic,true)==false and spawned==0,
        'an ambulance must not teleport its medic into a blocked spawn position')
    hooks.PlayerDeath.BGN_Medics_ClearDanger(killer)
    bgNPC:SpawnVehicleWithActor(medic,true)
    assert(spawned==1, 'the ambulance spawn must become available after the killer dies')
''')

gesture = realm(True)
gesture.execute('''
    bgNPC.Actor={Helpers={}}; bgNPC.Assert={Arg=function() end,NonEmptyString=function() end}
    function isbool(v) return type(v)=='boolean' end
    bgNPC.Table.Random=function(t) return t[1] end
    bgNPC.States={Register=function(n,_,v) bgNPC.States[n]=v end,
        HasAction=function(n,f) return bgNPC.States[n] and bgNPC.States[n][f]~=nil end,
        Call=function(n,f,actor,...) local s=bgNPC.States[n]; if s and s[f] then return s[f](actor,...) end end}
    playing=false
    bgNPC.Animator={Play=function() playing=true; return {time=5} end,Stop=function() playing=false end}
''')
load(gesture, 'actor/components/sh_state.lua', 'brain/fsm/states/sv_random_gesture.lua')
gesture.execute('''
    actor=setmetatable({mechanics={states_controller=true},data={},state_delay=0,
        state_data={state='walk',data={}},IsAlive=function() return true end,
        GetNPC=function() return {} end,StopWalk=function() end,
        ResetSequence=function() bgNPC.Animator.Stop() end}, {__index=bgNPC.Actor})
    setcv('bgn_module_custom_gestures',1)
    actor:SetState('random_gesture')
    assert(playing and actor:GetState()=='random_gesture', 'state entry must not cancel the gesture it just started')
    now=106
    bgNPC.States.random_gesture.update(actor,'random_gesture',actor:GetStateData())
    assert(not playing and actor:GetState()=='walk')
    setcv('bgn_module_custom_gestures',0)
    actor:SetState('random_gesture')
    assert(not playing and actor:GetState()=='walk')
    actor.is_animated=false
    actor.IsAnimationPlayed=function() return true end
    actor.IsSequenceFinished=function() return true end
    actor.GetNPC=function() return {} end
    actor.ResetSequence=function() error('static controller must not stop a custom gesture') end
    bgNPC.Actors.GetAll=function() return {actor} end
''')
load(gesture, 'systems/sv_static_animation_controller.lua')
gesture.execute('hooks.Think.BGN_ActorAnimationController()')
gesture.execute('''
    actor.is_animated=true
    actor.IsLoopSequence=function() return false end
    actor.PlayNextStaticSequence=function() return false end
    actor.ResetSequence=function(self) self.reset=true end
    hooks.Think.BGN_ActorAnimationController()
    assert(actor.reset, 'ordinary static sequences must still finish normally')
''')

animation_client = realm(False)
animation_client.execute('''
    RENDERGROUP_OPAQUE=1; EF_BONEMERGE=1; EF_BONEMERGE_FASTCULL=2
    function Model(v) return v end
    function Prop()
        return {valid=true,GetPos=function() return Vector() end,GetAngles=function() return {} end,
            GetModel=function() return 'model' end,GetSkin=function() return 0 end,GetBodyGroups=function() return {} end,
            LookupBone=function() return 1 end,SetPos=function() end,SetAngles=function() end,
            SetParent=function() end,AddEffects=function() end,SetSkin=function() end,
            SetNoDraw=function(self,v) self.hidden=v end,Remove=function(self) self.valid=false end}
    end
    ClientsideModel=function() return Prop() end
    original=function() end
    npc=Prop(); npc.RenderOverride=original
    weapon=Prop(); npc.GetActiveWeapon=function() return weapon end
    animator=Prop()
''')
load(animation_client, 'core/sh_animator.lua')
animation_client.execute('''
    local a=bgNPC.Animator
    local start=received['bgn.anim_start'].f
    start(nil,npc,animator,'dance',1,105)
    assert(a.IsPlaying(npc) and npc.RenderOverride~=original and weapon.hidden)
    a.Get(npc).model.valid=false
    hooks.Think.BGN_Animator()
    assert(not a.IsPlaying(npc) and npc.RenderOverride==original and not weapon.hidden,
        'a vanished client model must never leave an invisible actor')
    start(nil,npc,animator,'dance',1,105)
    now=105; hooks.Think.BGN_Animator()
    assert(not a.IsPlaying(npc) and npc.RenderOverride==original and not weapon.hidden,
        'the deadline must restore rendering even if the stop message is missed')
    start(nil,npc,animator,'dance',1,104)
    assert(not a.IsPlaying(npc), 'a delayed expired start must not hide a walking actor')
    start(nil,npc,animator,'dance',1,0)
    now=1000; hooks.Think.BGN_Animator()
    assert(a.IsPlaying(npc), 'looping animations have no automatic deadline')
    received['bgn.anim_stop'].f(nil,npc)
    assert(not a.IsPlaying(npc) and npc.RenderOverride==original)
''')

police_weapons = realm(True)
police_weapons.execute('''
    bgNPC.Assert={Arg=function() end}
    bgNPC.Util.GetCVar=function(name) return GetConVar(name) end
    bgNPC.cfg.melee_weapons={'weapon_stunstick','weapon_crowbar','none'}
    bgNPC.Table.HasValue=function(t,v) for _,x in ipairs(t) do if x==v then return true end end return false end
    table.HasValue=bgNPC.Table.HasValue
    list.GetForEdit=function() return {} end
    local protected=false
    list.Set('BGN_Modules','player_arrest',{IsProtected=function() return protected end})
    function protect(value) protected=value end
    function Weapon(class)
        return {valid=true,GetClass=function() return class end}
    end
    enemy={valid=true,pos=Vector(200,0,0),GetPos=function(self) return self.pos end,
        GetActiveWeapon=function(self) return self.weapon end,
        IsPlayer=function() return true end, IsNPC=function() return false end, IsNextBot=function() return false end,
        IsVehicle=function() return false end}
    npc={valid=true,pos=Vector(),weapons={},GetPos=function(self) return self.pos end,
        GetActiveWeapon=function(self) return self.active end,
        GetWeapon=function(self,class) return self.weapons[class] end,
        Give=function(self,class) self.weapons[class]=Weapon(class); return self.weapons[class] end,
        SelectWeapon=function(self,class) self.active=self.weapons[class] end,
        GetClass=function() return 'npc_metropolice' end}
    actor={class='npc_metropolice',state_data={},IsAlive=function() return true end,IsNPC=function() return true end,
        GetType=function() return 'police' end,GetNPC=function() return npc end,
        HasTeam=function(_,team) return team=='police' end,GetNearEnemy=function() return enemy end,
        GetActorWeapon=function() return 'weapon_pistol' end,
        GetStateData=function(self) return self.state_data end,
        GetBody=function() return {RemoveActiveWeapon=function() npc.active=nil end} end}
    function new_fight()
        actor.state_data={}
        npc.active=Weapon('weapon_stunstick')
    end
    function expect(class)
        bgNPC.Combat.EquipActor(actor)
        assert((npc.active and npc.active:GetClass())==class, 'unexpected police weapon: '..tostring(class))
    end
    setcv('bgn_disable_weapon_police',0)
    setcv('bgn_arrest_safe_weapons','weapon_fists, gmod_tool,weapon_physgun')
''')
load(police_weapons, 'api/sv_combat.lua')
police_weapons.execute('''
    npc.active=Weapon('weapon_stunstick')
    expect('weapon_stunstick') -- no attack, no kills
    enemy.bgn_last_attack=now
    expect('weapon_stunstick') -- an unarmed first offender
    enemy.bgn_has_killed=true
    expect('weapon_pistol') -- must switch away from an already equipped stick
    enemy.pos=Vector(75,0,0)
    expect('weapon_pistol') -- closing in must not downgrade a fight to melee
    enemy.bgn_last_attack=now-30
    expect('weapon_pistol') -- a pause in attacks must not downgrade the same fight either
    new_fight(); expect('weapon_stunstick') -- state changes release the escalation
    enemy.weapon=Weapon('weapon_smg1'); enemy.bgn_has_killed=nil
    expect('weapon_pistol') -- an armed enemy needs no first kill or recorded recent hit, even nearby
    enemy.weapon=Weapon('gmod_tool')
    expect('weapon_pistol') -- changing the target's weapon must not reset the same fight
    npc.active=Weapon('weapon_stunstick')
    expect('weapon_pistol') -- restore the pistol if another controller selects the baton
    enemy.pos=Vector(200,0,0)
    for _,class in ipairs({'gmod_tool','weapon_physgun','weapon_fists','weapon_crowbar'}) do
        new_fight()
        enemy.weapon=Weapon(class); expect('weapon_stunstick')
    end
    enemy.weapon=Weapon('weapon_smg1'); enemy.bgn_last_attack=now-10
    expect('weapon_pistol') -- a hostile ranged opponent must not be chased with a baton
    enemy.bgn_last_attack=now-9.99; expect('weapon_pistol')
    protect(true); expect(nil)
    assert(not actor.state_data.police_firearm, 'arrest must release firearm escalation')
    protect(false); expect('weapon_pistol')
    actor.state_data={}; enemy.weapon=nil; enemy.bgn_last_attack=nil
    expect('weapon_pistol') -- keep an already drawn pistol after reloading the addon
    actor.class='npc_combine_s'; enemy.bgn_last_attack=nil
    npc.active=nil; expect('weapon_pistol') -- other law enforcement keeps its existing rules
    npc.active=Weapon('weapon_shotgun'); expect('weapon_shotgun')
    actor.class='npc_metropolice'; enemy.weapon=nil; enemy.bgn_last_attack=now
    hooks.OnNPCKilled.BGN_PoliceLethalThreat({},enemy)
    assert(enemy.bgn_has_killed)
    expect('weapon_pistol') -- wanted statistics can have been reset after the first kill
    hooks.PlayerDeath.BGN_PoliceLethalThreat(enemy,nil,enemy)
    assert(not enemy.bgn_has_killed and not enemy.bgn_last_attack)
    new_fight()
    expect('weapon_stunstick')
''')
# The damage hook precedes the GMod-only continue statements in the surrender timer.
police_weapons.execute((ROOT / 'systems/arrest/sv_surrender.lua').read_text(encoding='utf-8-sig')
                       .split("timer.Create('BGN_Surrender'", 1)[0])
police_weapons.execute('''
    local victim={IsPlayer=function() return false end,IsNPC=function() return true end}
    local damage={GetAttacker=function() return enemy end,GetDamage=function() return 5 end}
    local record=hooks.EntityTakeDamage.BGN_Surrender_LastAttack
    record(victim,damage); assert(enemy.bgn_last_attack==now)
    enemy.bgn_last_attack=nil; damage.GetDamage=function() return 0 end
    record(victim,damage); assert(enemy.bgn_last_attack==nil)
    damage.GetDamage=function() return 5 end
    record(enemy,damage); assert(enemy.bgn_last_attack==nil)
    enemy.IsPlayer=function() return false end; enemy.IsNextBot=function() return true end
    record(victim,damage); assert(enemy.bgn_last_attack==now, 'NextBot attacks must count too')
    enemy.bgn_last_attack=nil
    hooks.EntityFireBullets.BGN_PoliceLastAttack(enemy)
    assert(enemy.bgn_last_attack==now, 'a missed shot must still count as an attack')
    enemy.GetActiveWeapon=nil
    assert(not bgNPC.Combat.CanPoliceShoot(enemy), 'unarmed third-party NextBots may have no weapon API')
''')

# Parse every changed/new Lua module with the same LuaJIT language version as GMod.
paths = ['actor/sh_actor.lua', 'api/sh_actors.lua', 'api/sh_statistics.lua',
         'modules/sv_followers_mod.lua', '../entities/npc_decentvehicle_passenger/init.lua',
         'core/sh_cvars.lua', 'systems/wanted/sh_wanted_class.lua', 'systems/wanted/sv_wanted_actions.lua',
         'core/sh_animator.lua', 'cvars/sh_cvars.lua', 'systems/sv_medics.lua',
         'systems/sv_static_animation_controller.lua', 'brain/fsm/states/sv_random_gesture.lua',
         'brain/fsm/states/sv_medic_revive.lua', 'ui/menu/cl_menu_pages.lua',
         'actor/sync/cl_sync.lua', 'actor/sync/sv_sync.lua', 'actor/cl_actor_voice.lua', 'actor/events/sv_self_damage.lua',
         'systems/wanted/cl_wanted_sync.lua', 'systems/arrest/sv_arrest.lua', 'nav/sh_node_graph.lua', 'nav/sv_nav.lua',
         'nav/legacy/sh_legacy_nodes.lua', 'nav/io/sh_route_dupe.lua', 'nav/generator/sv_generator.lua',
         'nav/providers/sv_custom_provider.lua', 'nav/io/sh_nav_editor.lua',
         'nav/io/sh_compile.lua', 'actor/events/sv_save_restore.lua',
         'modules/dv/sh_dv_vehicle.lua', 'actor/components/sh_vehicle.lua',
         'modules/dv/sv_car_damage_reaction.lua', '../entities/bgn_fakeplayer/shared.lua',
         '../entities/npc_decentvehicle_passenger/shared.lua',
         'ui/settings/cl_classic_settings.lua', 'actor/components/sh_movement.lua',
         'actor/body/sv_npc_body.lua', 'modules/dv/sv_pedestrian_traffic.lua', 'modules/dv/sv_vehicle_traffic.lua', '../entities/npc_dvbgn_police.lua']
for path in paths:
    client.execute('assert(loadstring(...))', (ROOT / path).read_text(encoding='utf-8-sig'))
assert (ROOT / 'ui/settings/cl_classic_settings.lua').read_text(encoding='utf-8-sig').count('OpenNewMenuButton(panel)') == 2
spawns = realm(True)
spawns.execute('''
    local angles={}
    angles.__index=angles
    function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},angles) end
    function angles.__add(a,b) return Angle(a.p+b.p,a.y+b.y,a.r+b.r) end
    function angles.__sub(a,b) return Angle(a.p-b.p,a.y-b.y,a.r-b.r) end
    local vec=getmetatable(Vector())
    function vec.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    function vec:Angle() return Angle(0,math.deg(math.atan2(self.y,self.x)),0) end
    local function wheels(x,y)
        return {CustomWheels=true,CustomWheelPosFL=Vector(x,y+10),CustomWheelPosFR=Vector(x,y-10),
            CustomWheelPosRL=Vector(-x,-y+10),CustomWheelPosRR=Vector(-x,-y-10)}
    end
    local definitions={standard={SpawnAngleOffset=90,Members=wheels(1,0)},sideways={Members=wheels(0,-1)},reversed={Members=wheels(-1,0)}}
    bgNPC.Util.EntityTimer=function() end
    list={Get=function(name) return name=='simfphys_vehicles' and definitions or {native={Class='prop_vehicle_jeep',Model='car.mdl'}} end}
    simfphys={SpawnVehicleSimple=function(class,pos,ang) return {valid=true,class=class,pos=pos,ang=ang} end}
    ents={Create=function()
        return {valid=true,SetModel=function() end,SetPos=function() end,SetAngles=function() end,
            Spawn=function() end,Activate=function() end}
    end}
''')
spawn_source = (ROOT / 'spawner/sv_dv_spawner.lua').read_text(encoding='utf-8-sig')
spawns.execute(spawn_source.split('local function GetNearPoints', 1)[0] + 'function bgNPC:SpawnVehicle(' + spawn_source.split('function bgNPC:SpawnVehicle(', 1)[1].split('function bgNPC:SpawnVehicleWithActor', 1)[0])
spawns.execute('''
    for _, heading in ipairs({0,45,180,-90}) do
        for class, local_forward in pairs({standard=0,sideways=-90,reversed=180}) do
            local vehicle=bgNPC:SpawnVehicle(class,Vector(10,20,50),Angle(0,heading,0))
            assert(vehicle.ang.y+local_forward==heading, 'physical front must face along the road')
            assert(vehicle.pos==Vector(10,20,50))
            assert(vehicle.isBgnVehicle, 'spawned cars must be marked independently of their AI')
        end
    end
    local vehicle=bgNPC:SpawnVehicle('sideways',Vector(10,20,50),Angle(0,45,0),Vector(0,0,5),Angle(0,10,0))
    assert(vehicle.ang.y==145 and vehicle.pos==Vector(10,20,55), 'actor offsets must also reach simfphys')
    assert(bgNPC:SpawnVehicle('native').isBgnVehicle, 'Source vehicles must be marked too')
''')
cleanup = realm(True)
cleanup.execute('''
    setcv('bgn_enable',1); setcv('bgn_enable_dv_support',1)
    setcv('bgn_spawn_radius',3000); setcv('bgn_vehicle_cleanup_time',120)
    bgNPC.Vision={PlayerCanSeePos=function(_,p) return visible and p.x==100 end}
    local eye={valid=true,EyePos=function() return Vector(500,500,64) end}
    function NewPlayer()
        return {valid=true,GetPos=function() return Vector() end,GetVehicle=function(self) return self.seat end,
            GetViewEntity=function() return eye end}
    end
    viewers={NewPlayer()}
    player.GetAll=function() return viewers end; player.GetCount=function() return #viewers end
    util.TraceLine=function(t)
        assert(t.start==eye:EyePos(), 'trace from the active camera')
        return {Hit=not (edge_clear and t.endpos.x==100),Entity=trace_entity}
    end
    function NewCleanupCar(marked)
        now=0; visible=false; edge_clear=false; trace_entity=nil
        viewers={NewPlayer()}; setcv('bgn_vehicle_cleanup_time',120)
        local car={valid=true,isBgnVehicle=marked,pos=Vector()}
        function car:GetPos() return self.pos end
        function car:OBBMins() return Vector(-100,-40,0) end
        function car:OBBMaxs() return Vector(100,40,60) end
        function car:OBBCenter() return Vector(0,0,30) end
        function car:LocalToWorld(p) return self.pos+p end
        function car:NearestPoint() return self:LocalToWorld(Vector(100,40,60)) end
        function car:GetParent() end
        local provider={car=car,driver=true}
        function provider:GetVehicle() return car end
        function provider:GetDriver() return self.driver end
        function provider:GetPassengers() return {} end
        function provider:RemoveActors() end
        function provider:IsValidAI() return false end
        function provider:Remove() car.valid=false end
        bgNPC.DVCars={provider}
        return provider,car
    end
''')
load(cleanup, 'spawner/sv_dv_remover.lua')
cleanup.execute('''
    local tick=timers.BGN_Timer_DVCars_Remover
    local p,c=NewCleanupCar(true); tick()
    now=119; tick(); assert(c.valid, 'allow the full grace period')
    now=120; tick(); assert(not c.valid and #bgNPC.DVCars==0, 'remove a hidden stuck car even near a player')
    p,c=NewCleanupCar(true); tick(); c.pos=Vector(60,0,0); now=60; tick()
    c.pos=Vector(-60,0,0); now=120; tick(); assert(not c.valid, 'rocking is not progress')
    p,c=NewCleanupCar(true); tick(); c.pos=Vector(129,0,0); now=60; tick()
    now=179; tick(); assert(c.valid, 'real progress resets the stuck timer')
    now=180; tick(); assert(not c.valid)
    p,c=NewCleanupCar(true); p.driver=nil; tick()
    c.pos=Vector(200,0,0); now=60; tick(); c.pos=Vector(400,0,0); now=120; tick()
    assert(not c.valid, 'a rolling driverless car must still expire')
    p,c=NewCleanupCar(true); p.driver=nil; tick(); p.driver=true
    c.pos=Vector(200,0,0); now=60; tick(); c.pos=Vector(400,0,0); now=120; tick()
    assert(c.valid, 'a returning driver resets the empty timer')
    p,c=NewCleanupCar(true); tick(); edge_clear=true; now=120; tick()
    assert(c.valid, 'a clear ray to an edge protects a car even outside the field of view')
    edge_clear=false; visible=true; tick(); assert(c.valid, 'FOV protection does not require a clear ray')
    visible=false; viewers[2]=NewPlayer(); viewers[2].seat=c; tick()
    assert(c.valid, 'any player inside the car prevents cleanup')
    viewers[2].seat=nil; trace_entity={valid=true,GetParent=function() return c end}; tick()
    assert(c.valid, 'hitting a child of the car counts as seeing it')
    trace_entity=nil; tick(); assert(not c.valid)
    p,c=NewCleanupCar(false); tick(); now=1000; tick(); assert(c.valid, 'foreign cars are not force-cleaned')
    p,c=NewCleanupCar(true); setcv('bgn_vehicle_cleanup_time',0); tick(); now=1000; tick(); assert(c.valid)
''')
access = realm(True)
access.execute('''
    bgNPC.Assert={Arg=function() end}; bgNPC.Util.NextId=function() return 1 end
    bgNPC.Table.HasValue=function() return false end; DecentVehicleDestination={}
    FindMetaTable=function() return {} end
    string.Explode=function(sep,s)
        local result={}; local start=1
        while true do local at=s:find(sep,start,true); if not at then result[#result+1]=s:sub(start); return result end
            result[#result+1]=s:sub(start,at-1); start=at+#sep end
    end
''')
load(access, 'modules/dv/sh_dv_vehicle.lua')
access.execute('''
    local a={vehicle_speed={calm=250},GetStateGroupName=function() return 'calm' end}
    local dv={Waypoint={SpeedLimit=400},GetCurrentMaxSpeed=function() return 200 end,
        bgnProvider={GetDriver=function() return a end}}
    BGN_VEHICLE:OverrideVehicle(dv)
    assert(dv:GetCurrentMaxSpeed()==125, 'speed override retains the original DV corner slowdown')
    a.vehicle_speed=nil; a.vehicle_multiply_speed={calm=2}
    assert(dv:GetCurrentMaxSpeed()==400, 'state multiplier retains DV slowdown')
    a.vehicle_multiply_speed=nil
    assert(dv:GetCurrentMaxSpeed()==200, 'ordinary traffic uses the original DV speed')
    local car={valid=true,GetDriver=function() end,CallOnRemove=function() end,GetMaxHealth=function() return 0 end}
    local police={HasTeam=function(_,team) return team=='police' end,IsAlive=function() return true end}
    local citizen={HasTeam=function() return false end,GetVehicleGroup=function() return 'residents' end}
    local p=BGN_VEHICLE:Instance(car,'police','police')
    assert(car.bgnPoliceVehicle and p:CanUse(police) and not p:CanUse(citizen))
    citizen.last_vehicle=p
    assert(not p:CanBoard(citizen) and not p:CanSeize(citizen), 'last vehicle and seizure cannot bypass police access')
    assert(p:SetDriver(citizen)==false and p:AddPassenger(citizen)==false)
    assert(not p.driver and #p.passengers==0)
    p:SetGroup('residents'); assert(not p:CanUse(citizen), 'group changes cannot remove police designation')
    local ambulance=BGN_VEHICLE:Instance({valid=true,CallOnRemove=function() end},'medics|npc_dvbgn_police|ambulance|2','medic')
    assert(ambulance:CanUse(citizen), 'police AI class does not make an ambulance a police car')
    local seat={GetClass=function() return 'prop_vehicle_prisoner_pod' end,GetDriver=function() end}
    car.GetChildren=function() return {seat} end
    p.ai={valid=true}; p.driver=police; p.passengers={police}; p.passengers_limit=2
    local crew={last_vehicle=p,HasTeam=police.HasTeam}
    assert(p:CanBoard(crew), 'returning crew may use a free passenger seat after their driver boards')
    car.GetMaxHealth=function() return 100 end; car.Health=function() return 20 end
    assert(not p:CanBoard(crew), 'police do not reboard a critically damaged car and immediately exit again')
    car.GetMaxHealth=function() return 0 end
    car.GetDriver=function() return p.ai end
    assert(p:CanBoard(crew), 'simfphys exposes the DV remote driver through GetDriver')
    car.GetDriver=function() return {valid=true} end
    assert(not p:CanBoard(crew), 'a player driver still blocks autonomous boarding')
    car.GetDriver=function() end
    p.passengers_limit=1; assert(not p:CanBoard(crew), 'full crew vehicles are not boardable')
''')
movement = realm(True)
movement.execute('''
    bgNPC.Actor={}; bgNPC.Assert={Arg=function() end}; SCHED_FORCED_GO=1; SCHED_FORCED_GO_RUN=2
''')
load(movement, 'actor/components/sh_movement.lua')
movement.execute('''
    local cleared=0
    local a=setmetatable({dvDetour={},dvAvoidActive=true,body={ClearSchedule=function() cleared=cleared+1 end}}, {__index=bgNPC.Actor})
    a:StopWalk()
    assert(cleared==1 and not a.dvDetour and not a.dvAvoidActive, 'stopping an idle detour must really stop it')
    bgNPC.Class=function() return {} end
    CAP_DUCK=0; CAP_MOVE_SHOOT=0; CAP_USE=0; CAP_TURN_HEAD=0; CAP_SQUAD=0; CAP_AIM_GUN=0
    CAP_AUTO_DOORS=0; CAP_OPEN_DOORS=0
''')
load(movement, 'actor/body/sv_npc_body.lua')
movement.execute('''
    local schedules=0
    local e={valid=true,schedule=0,IsCurrentSchedule=function(self,id) return self.schedule==id end,
        SetLastPosition=function() end,GetCurrentSchedule=function(self) return self.schedule end,
        GetNPCState=function() return 0 end,SetSchedule=function(self,id) self.schedule=id; schedules=schedules+1 end}
    local b=setmetatable({ent=e,actor={}}, {__index=bgNPC.NPCBody})
    b:MoveTo(Vector(100,0,0),true); b:MoveTo(Vector(100,0,0),true)
    assert(schedules==1, 'unchanged goals must not reset a running NPC schedule')
    e.schedule=0; b:MoveTo(Vector(100,0,0),true)
    assert(schedules==2, 'an interrupted schedule must be restarted')
    b:MoveTo(Vector(150,0,0),true); assert(schedules==3, 'new goals must reach the engine')
''')
print('PASS: existing regressions, vehicle body lifecycle/identity/sync, spawn headings, cleanup, police access, detours and LuaJIT syntax')
