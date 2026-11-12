"""Run isolated Animator tests outside GMod (requires the existing lupa dependency)."""
from pathlib import Path
from lupa.luajit21 import LuaRuntime

root = Path(__file__).resolve().parents[1] / 'lua'
for test in ['sh_animator.lua', 'cl_animator.lua']:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        function Vector() return {} end
        function Angle() return {} end
        function Color(...) return {...} end
        function isfunction(v) return type(v) == 'function' end
        function isnumber(v) return type(v) == 'number' end
        SCHED_NPC_FREEZE=10; NPC_STATE_SCRIPT=7
        EF_BONEMERGE=1; EF_BONEMERGE_FASTCULL=2; RENDERGROUP_OPAQUE=0
        tests={}; bgNPC={Test={Add=function(name,f) tests[name]=f end}}
    ''')
    lua.globals().CompileFile = lambda name: lua.eval('loadstring')(
        (root / name).read_text(encoding='utf-8-sig'))
    lua.execute((root / 'background_npcs_core/tests' / test).read_text(encoding='utf-8'))
    lua.execute('for name,f in pairs(tests) do f(function(ok,message) assert(ok,name .. ": " .. message) end) end')
    print(test + ': passed')

