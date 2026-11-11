"""Door-scene regressions outside GMod: python tools/test_scenic.py (requires lupa)."""
from pathlib import Path

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'lua/background_npcs_core'
lua = LuaRuntime()
lua.execute('''
    SERVER=true; CLIENT=false; MASK_SOLID_BRUSHONLY=1
    function isstring(v) return type(v)=='string' end
    function isnumber(v) return type(v)=='number' end
    function istable(v) return type(v)=='table' end
    function isbool(v) return type(v)=='boolean' end
    function IsValid(v) return type(v)=='table' and v.valid==true end
    function CurTime() return now or 100 end
    local vec={}; vec.__index=vec
    function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},vec) end
    function vec.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
    function vec.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    function vec.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
    function vec.__unm(a) return a*-1 end
    function vec:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
    function vec:Distance(b) local d=self-b; return math.sqrt(d:Dot(d)) end
    function vec:Angle() return Angle(0,math.deg(math.atan2(self.y,self.x)),0) end
    local ang={}; ang.__index=ang
    function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},ang) end
    function ang:Forward() local y=math.rad(self.y); return Vector(math.cos(y),math.sin(y)) end
    function ang:Right() local y=math.rad(self.y); return Vector(math.sin(y),-math.cos(y)) end
    vector_origin=Vector()
    bgNPC={Actor={Helpers={}},States={},cfg={},Assert={Arg=function() end,NonEmptyString=function() end},
        Tasks={Add=function() end},Commands={Register=function(n,v) commands[n]=v end},
        Util={Log=function() end}}
    commands={}; pending={}; hooks={}; undos={}
    timer={Simple=function(_,f) pending[#pending+1]=f end}
    hook={Run=function() end,Add=function(n,id,f) hooks[n]=hooks[n] or {}; hooks[n][id]=f end}
    undo={Create=function() end,SetPlayer=function() end,AddFunction=function(f) undos[#undos+1]=f end,Finish=function() end}
    bgNPC.Doors={held={},Release=function() end,IsClosed=function(d) return d.state==0 end}
    bgNPC.Net={Send=function() end,ToolRPC=function(_,_,text) last_report=text end}
    bgNPC.Actors={Get=function(n) return n and n.actor end}
    function GetConVar() return {GetFloat=function() return 3000 end} end
    function MsgN() end
    util={TraceHull=function() return {Hit=blocked} end,TraceLine=function(t)
        if t.start.x==t.endpos.x and t.start.y==t.endpos.y then
            return {Hit=true,HitPos=Vector(t.start.x,t.start.y,0),HitNormal=Vector(0,0,1)}
        end
        return {Hit=false}
    end}
    function table.RemoveByValue(t,v) for i,x in ipairs(t) do if x==v then table.remove(t,i); return end end end
    function bgNPC:IsValidSpawnArea() return true end
    function bgNPC:IsHiddenSpawnPosition() return true end
''')
for path in ('core/sh_util.lua', 'api/sh_states.lua', 'actor/components/sh_state.lua',
             'config/states/sh_scenic.lua', 'systems/scenic/sv_scenic_finders.lua',
             'systems/scenic/sv_scenic_spawner.lua', 'brain/fsm/states/sh_scenic_npc.lua', 'debug/sv_scenic.lua'):
    lua.execute((ROOT / path).read_text(encoding='utf-8-sig'), name=path)
lua.execute('''
    bgNPC.Util.IsVectorInWater=function() return false end
    bgNPC.States.Register('walk','calm')
    function Door(class,yaw,thin_y)
        local d={valid=true,class=class,state=class=='prop_door_rotating' and 0 or 1,ang=Angle(0,yaw)}
        function d:GetClass() return self.class end
        function d:EntIndex() return 1 end
        function d:GetInternalVariable(key)
            if key==(self.class=='prop_door_rotating' and 'm_eDoorState' or 'm_toggle_state') then return self.state end
        end
        function d:OBBMins() return thin_y and Vector(-24,-6,0) or Vector(-6,-1,0) end
        function d:OBBMaxs() return thin_y and Vector(24,6,108) or Vector(6,47,108) end
        function d:OBBCenter() return (self:OBBMaxs()+self:OBBMins())*0.5 end
        function d:GetForward() return self.ang:Forward() end
        function d:GetRight() return self.ang:Right() end
        function d:LocalToWorld(p) return self:GetForward()*p.x-self:GetRight()*p.y+Vector(0,0,p.z) end
        return d
    end
    spawns=0
    function bgNPC:SpawnActor(kind,pos,effect,require_hidden)
        spawns=spawns+1
        last_hidden=require_hidden
        local npc={valid=true,pos=pos,SetAngles=function(self,a) self.ang=a end,
            GetModel=function() return 'custom_actor_model.mdl' end,
            GetClass=function() return 'npc_metropolice' end,GetSequence=function() return 1 end,
            GetSequenceName=function() return 'adoorknock' end,EntIndex=function() return spawns end,
            SetModel=function() error('scenic must preserve normal actor model selection') end,
            SetPos=function(self,p) self.pos=p end,GetPos=function(self) return self.pos end}
        local a=setmetatable({uid=spawns,mechanics={states_controller=true},data={},state_delay=0,
            state_data={state='none',data={}},GetNPC=function() return npc end,
            Health=function() return 50 end,IsAlive=function(self) return not self.removed end,
            IsValidSequence=function() return sequence_supported~=false end,
            StopWalk=function() end,ResetSequence=function(self) self.playing=false end,
            PlayStaticSequence=function(self) self.playing=true end,Remove=function(self) self.removed=true end},
            {__index=bgNPC.Actor})
        npc.actor=a; return a
    end
    local scene=bgNPC.cfg.scenic.door_knock
    for _,def in pairs(bgNPC.cfg.scenic) do
        for _,member in ipairs(def.members) do assert(not member.models, 'built-in scenes must use actor models') end
    end
    -- A legacy custom scene must not bypass normal spawn/model hooks either.
    scene.members[1].models={'forced_scene_model.mdl'}
    local spots=bgNPC.Scenic.Spots
    for _,class in ipairs({'prop_door_rotating','func_door_rotating'}) do
        for _,yaw in ipairs({0,90,180,270,37}) do
            for _,thin_y in ipairs({false,true}) do
                local d=Door(class,yaw,thin_y)
                local spot=assert(spots.Find('door',d,scene))
                local member=assert(bgNPC.Scenic.Plan(scene,spot)).members[1]
                local toward=d:LocalToWorld(d:OBBCenter())-member.pos; toward.z=0
                local left=-member.ang:Right()
                assert(math.abs(left:Dot(toward)-toward:Distance(Vector()))<0.001,
                    'adoorknock reaches along local +Y, on either side and at any door yaw')
                -- Measured on models/police.mdl at the knock: hand is 33 units along local +Y.
                assert(math.abs(toward:Distance(Vector())-6-33)<=4, 'knuckles must reach the door surface')
                local item=assert(bgNPC.Scenic.Create('door_knock',scene,spot))
                table.remove(pending,1)()
                local a=item.actors[1]
                assert(a:GetNPC():GetModel()=='custom_actor_model.mdl')
                assert(a:GetStateData().door==d and a.playing, 'delayed start must retain the actual door')
                assert(not a:SetState('walk') and a:HasState('scenic_npc'), 'calm transitions cannot end a closed-door scene')
                for _,state in ipairs({0,1,2,3}) do
                    d.state=state
                    assert((spots.Find('door',d,scene)~=nil)==(state==(class=='prop_door_rotating' and 0 or 1)),
                        'open, opening and closing doors must not provide spots')
                end
                d.state=class=='prop_door_rotating' and 1 or 2
                a:CallStateAction(nil,'update',a:GetState(),a:GetStateData())
                assert(a:HasState('none') and not a.playing and a:IsAlive(), 'opening releases the animation and actor')
                bgNPC.Scenic.Remove(item)
                assert(a:IsAlive(), 'scene cleanup must preserve released residents')
            end
        end
    end
    local d=Door('prop_door_rotating',0,false)
    local spot=assert(spots.Find('door',d,scene))
    local a=bgNPC:SpawnActor('police',spot.pos)
    a:SetState('scenic_npc',{seq='adoorknock',door=d},true)
    d.valid=false
    a:CallStateAction(nil,'update',a:GetState(),a:GetStateData())
    assert(a:HasState('none') and not a.playing, 'removed doors also release the actor')
    a:SetState('scenic_npc',{seq='cheer1'},true)
    a:CallStateAction(nil,'update',a:GetState(),a:GetStateData())
    assert(a:HasState('scenic_npc') and a.playing, 'scenes without doors are unchanged')
    a:SetState('defense')
    assert(a:HasState('defense') and not a.playing, 'danger must still interrupt scenes')
    d.valid=true; d.state=0
    local delayed=assert(bgNPC.Scenic.Create('door_knock',scene,spot))
    d.state=1
    table.remove(pending,1)()
    local late=delayed.actors[1]
    late:CallStateAction(nil,'update',late:GetState(),late:GetStateData())
    assert(late:HasState('none') and not late.playing, 'opening during delayed setup must not trap the actor')
    bgNPC.Scenic.Remove(delayed)
    d.state=0
    local admin={valid=true,IsAdmin=function() return true end,IsPlayer=function() return true end,GetInfo=function() return 'en' end,
        GetEyeTrace=function() return {Hit=true,Entity=d} end}
    commands.bgn_scenic_spawn.server(admin,nil,{'door_knock'})
    table.remove(pending,1)()
    local manual=bgNPC.Scenic.active[1].actors[1]
    assert(manual:GetStateData().door==d, 'admin command must use the door finder and retain its entity')
    local count=spawns
    d.state=1; commands.bgn_scenic_spawn.server(admin,nil,{'door_knock'})
    d.class='prop_physics'; commands.bgn_scenic_spawn.server(admin,nil,{'door_knock'})
    assert(spawns==count, 'manual door scenes must reject an opening door or a non-door')
    blocked=true; d.class='prop_door_rotating'; d.state=0
    assert(not spots.Find('door',d,scene), 'no scene inside an obstructed hull')
    local manual_only={sky_watch=true,door_brace=true,couch_couple=true,couch_lying=true,radio_operator=true}
    local automatic,total=0,0
    for id,def in pairs(bgNPC.cfg.scenic) do
        total=total+1
        assert((def.weight==0)==(manual_only[id]==true), 'only the agreed five scenes are manual-only')
        if def.weight>0 then automatic=automatic+1 end
    end
    assert(total==26 and automatic==21)
    scenic_definitions=bgNPC.cfg.scenic
    bgNPC.cfg.scenic={manual={weight=0}}
    player={GetHumans=function() return {{}} end}
    spots.Seeds=function() error('an empty automatic pool must not select manual scenes, even at random roll zero') end
    local random=math.random; math.random=function() return 0 end
    assert(not bgNPC.Scenic.TrySpawn())
    math.random=random
''')
lua.execute('''
    bgNPC.cfg.scenic=scenic_definitions; blocked=false
    D=bgNPC.Scenic.Debug
    admin={valid=true,admin=true,IsPlayer=function() return true end,IsAdmin=function(self) return self.admin end,GetInfo=function() return 'en' end}
    other={valid=true,IsPlayer=admin.IsPlayer,IsAdmin=function() return true end,GetInfo=admin.GetInfo}
    trace={Hit=true,Entity=Door('prop_door_rotating',0,false)}
    local count=spawns
    admin.admin=false
    local item,reason=D.Spawn(admin,'door_knock',trace)
    assert(not item and reason=='admin' and spawns==count, 'a non-admin cannot request visible placement')
    assert(not bgNPC.Scenic.Create('door_knock',bgNPC.cfg.scenic.door_knock,{},nil,admin), 'factory enforces the debug owner permission too')
    assert(not D.DoorTest(admin,trace) and spawns==count, 'door tests also enforce admin rights')
    admin.admin=true
    assert(not D.Spawn(admin,'unknown',trace) and spawns==count, 'scene IDs are validated before spawning')
    bgNPC.IsHiddenSpawnPosition=function() return false end
    local spot=assert(bgNPC.Scenic.Spots.Find('door',trace.Entity,bgNPC.cfg.scenic.door_knock))
    item=assert(bgNPC.Scenic.Create('door_knock',bgNPC.cfg.scenic.door_knock,spot))
    assert(last_hidden==true, 'automatic creation still requests hidden actor spawning')
    table.remove(pending,1)()
    assert(item.removed and not item.actors[1]:IsAlive(), 'automatic delayed setup still rejects visible positions')
    item=assert(D.Spawn(admin,'door_knock',trace))
    bgNPC.States.Register('old_seat','calm',{stop=function(a) a:GetNPC():SetPos(Vector(999,999,999)) end})
    item.actors[1]:SetState('old_seat',nil,true)
    table.remove(pending,1)()
    assert(item.actors[1]:GetNPC():GetPos().z==0, 'old seating cleanup runs before final scene placement')
    assert(last_hidden==false and item.actors[1]:HasState('scenic_npc'), 'admin debug placement works while watched')
    assert(not D.Remove(other,item) and item.actors[1]:IsAlive(), 'another owner cannot remove the test')
    item.actors[1]:SetState('none',nil,true)
    undos[#undos]()
    assert(not item.actors[1]:IsAlive() and item.debug_removed, 'Undo removes owned actors that already left the scene')
    item=assert(D.Spawn(admin,'door_knock',trace))
    assert(D.Remove(admin,item)); table.remove(pending,1)()
    assert(not item.started and not item.actors[1]:IsAlive(), 'removal before delayed setup cannot restart the scene')
    item=assert(D.Spawn(admin,'door_knock',trace))
    admin.admin=false; table.remove(pending,1)()
    assert(item.removed and not item.actors[1]:IsAlive(), 'permission revocation cancels pending debug setup')
    admin.admin=true
    sequence_supported=false
    item=assert(D.Spawn(admin,'door_knock',trace)); table.remove(pending,1)()
    assert(item.failures[1].model=='custom_actor_model.mdl' and item.failures[1].reason=='sequence', 'unsupported normal models produce useful diagnostics')
    sequence_supported=true
    item=assert(D.Spawn(admin,'door_knock',trace)); table.remove(pending,1)()
    hooks.PlayerDisconnected.BGN_ScenicDebug(admin)
    assert(item.debug_removed and not item.actors[1]:IsAlive(), 'disconnect cleans up the owner tests')
    TOOL={GetOwner=function() return admin end,GetClientInfo=function() return 'door_knock' end}
''')
lua.execute((ROOT.parent / 'weapons/gmod_tool/stools/bgn_scenic_debug.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
    now=200; admin.admin=false
    local count=spawns
    assert(not TOOL:LeftClick(trace) and spawns==count, 'Tool cannot bypass the server permission gate')
    admin.admin=true
    assert(TOOL:LeftClick(trace)); table.remove(pending,1)()
    assert(not TOOL:LeftClick(trace), 'holding fire cannot flood spawns')
    TOOL:Report(); assert(last_report:find('scenic_npc',1,true) and last_report:find('custom_actor_model.mdl',1,true))
    assert(TOOL:RightClick({Entity=TOOL.LastItem.actors[1]:GetNPC()}))
    assert(TOOL.SelectedActor==TOOL.LastItem.actors[1], 'right click selects the actual actor')
    assert(TOOL:Reload() and TOOL.LastItem.debug_removed, 'reload removes only the last owned test')
    local chair={valid=true,occupied=true}
    bgNPC.States.Call('scenic_npc','stop',{GetNPC=function() return {valid=false} end},'scenic_npc',{back={chair=chair}})
    assert(not chair.occupied, 'removed scenic bodies must still release chair occupancy')
''')
print('PASS: scenic placement/lifecycle/models, debug permissions/visibility/ownership/Undo, Tool controls and seat release')
