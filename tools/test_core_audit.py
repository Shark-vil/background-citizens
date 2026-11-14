"""Run the isolated core audit regressions: python tools/test_core_audit.py (lupa)."""
from pathlib import Path
import subprocess
import sys

from lupa.luajit21 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1] / 'lua'
BASELINE = 'cde2f701269b1047021da53c0fa9554235be0db8'
lua = LuaRuntime(unpack_returned_tuples=True)
def source(path):
    if '--baseline' in sys.argv and '/tests/' not in path:
        return subprocess.check_output(['git', 'show', f'{BASELINE}:lua/{path}'], cwd=ROOT.parent).decode('utf-8-sig')
    return (ROOT / path).read_text(encoding='utf-8-sig')


def compilable_source(path):
    text = source(path)
    if path.endswith('/spawner/sv_spawner.lua'):
        # The tested SpawnActor factory has no GLua continue; unrelated search helpers do.
        text = text.split('local function IsValidSpawnFilter', 1)[0] + text[text.index('do\n  local random_models_storage'):]
    if path.endswith('/systems/sv_npc_look_at_object.lua'):
        # The exercised valid-object paths do not take these GLua continue branches.
        text = text.replace('continue', 'break')
    return text


lua.globals().read_source = compilable_source
lua.execute('''
    SERVER=true; CLIENT=false
    bit=require('bit')
    function istable(v) return type(v)=='table' end
    function isstring(v) return type(v)=='string' end
    function isnumber(v) return type(v)=='number' end
    function isfunction(v) return type(v)=='function' end
    function isbool(v) return type(v)=='boolean' end
    function math.Clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
    function isentity(v) return false end
    local vec={}; vec.__index=vec
    function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0},vec) end
    function vec:DistToSqr(b) return (self.x-b.x)^2+(self.y-b.y)^2+(self.z-b.z)^2 end
    function vec.__eq(a,b) return a.x==b.x and a.y==b.y and a.z==b.z end
    function vec.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
    function vec.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
    function vec.__mul(a,b) return Vector(a.x*b,a.y*b,a.z*b) end
    function vec:Distance(b) return math.sqrt(self:DistToSqr(b)) end
    function vec:Angle() return Angle(0,0,0) end
    local ang={}; ang.__index=ang
    function Angle(p,y,r) return setmetatable({p=p or 0,y=y or 0,r=r or 0},ang) end
    function ang:Forward() return Vector(1,0,0) end
    function isvector(v) return getmetatable(v)==vec end
    function isangle(v) return getmetatable(v)==ang end
    function IsColor() return false end
    function IsValid(v) return istable(v) and v.valid==true end
    function CompileFile(path) return assert(loadstring(read_source(path),'@'..path)) end
    function include(path) return CompileFile(path)() end
    function table.Copy(v)
        if not istable(v) then return v end
        local out={}; for k,item in pairs(v) do out[k]=table.Copy(item) end; return out
    end
    function table.Count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
    function string.Explode(sep,s)
        local out={}; for word in s:gmatch('[^'..sep..']+') do out[#out+1]=word end; return out
    end
    function string.GetFileFromFilename(s) return s:match('[^/]+$') end
    function SortedPairs(t)
        local keys={}; for k in pairs(t) do keys[#keys+1]=k end; table.sort(keys)
        local i=0; return function() i=i+1; local k=keys[i]; if k then return k,t[k] end end
    end
    FCVAR_ARCHIVE=1; COLLISION_GROUP_NONE=0; COLLISION_GROUP_NPC=9; COLLISION_GROUP_NPC_SCRIPTED=19
    TYPE_NIL=0; TYPE_BOOL=1; TYPE_NUMBER=2; TYPE_STRING=3; TYPE_TABLE=4; TYPE_ENTITY=5; TYPE_VECTOR=6; TYPE_ANGLE=7
    function TypeID(v)
        if isvector(v) then return TYPE_VECTOR end
        if isangle(v) then return TYPE_ANGLE end
        return ({['nil']=0,boolean=1,number=2,string=3,table=4})[type(v)] or -1
    end
    cvars={AddChangeCallback=function() end}
    concommand={Add=function() end}
    hook={Add=function() end}
    function MsgN() end
    tests={}
    bgNPC={Commands={Register=function() end},Test={Add=function(n,f) tests[n]=f end}}
''')
for path in ('core/sh_class.lua', 'core/sh_util.lua', 'api/sh_assert.lua',
             'tests/sv_engineering_audit.lua'):
    lua.execute(source('background_npcs_core/' + path), name=path)
lua.execute('''
    local failed,passed=0,0
    for name,fn in SortedPairs(tests) do
        local ok,err=pcall(fn,function(value,message) assert(value,message) end)
        if ok then passed=passed+1; print('PASS: '..name)
        else failed=failed+1; print('FAIL: '..name..': '..tostring(err)) end
    end
    assert(failed==0, failed..' audit test(s) failed')
    print(passed..' audit tests passed')
''')
