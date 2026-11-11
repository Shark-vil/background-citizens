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
    function CurTime() return 100 end
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
    commands={}; pending={}
    timer={Simple=function(_,f) pending[#pending+1]=f end}
    hook={Run=function() end}
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
             'systems/scenic/sv_scenic_spawner.lua', 'brain/fsm/states/sh_scenic_npc.lua'):
    lua.execute((ROOT / path).read_text(encoding='utf-8-sig'), name=path)
lua.execute('''
    bgNPC.Util.IsVectorInWater=function() return false end
    bgNPC.States.Register('walk','calm')
    function Door(class,yaw,thin_y)
        local d={valid=true,class=class,state=class=='prop_door_rotating' and 0 or 1,ang=Angle(0,yaw)}
        function d:GetClass() return self.class end
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
    function bgNPC:SpawnActor(_,pos)
        spawns=spawns+1
        local npc={valid=true,pos=pos,SetAngles=function(self,a) self.ang=a end,
            GetModel=function() return 'custom_actor_model.mdl' end,
            SetModel=function() error('scenic must preserve normal actor model selection') end,
            SetPos=function(self,p) self.pos=p end,GetPos=function(self) return self.pos end}
        local a=setmetatable({mechanics={states_controller=true},data={},state_delay=0,
            state_data={state='none',data={}},GetNPC=function() return npc end,
            IsAlive=function(self) return not self.removed end,IsValidSequence=function() return true end,
            StopWalk=function() end,ResetSequence=function(self) self.playing=false end,
            PlayStaticSequence=function(self) self.playing=true end,Remove=function(self) self.removed=true end},
            {__index=bgNPC.Actor})
        return a
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
    local admin={valid=true,GetEyeTrace=function() return {Entity=d} end}
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
    bgNPC.cfg.scenic={manual={weight=0}}
    player={GetHumans=function() return {{}} end}
    spots.Seeds=function() error('an empty automatic pool must not select manual scenes, even at random roll zero') end
    local random=math.random; math.random=function() return 0 end
    assert(not bgNPC.Scenic.TrySpawn())
    math.random=random
''')
print('PASS: scenic door alignment/lifecycle, actor models, manual-only scenes and admin spawn')
