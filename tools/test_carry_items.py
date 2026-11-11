"""Shared carry selection rules: python tools/test_carry_items.py (requires lupa)."""
from pathlib import Path
from lupa.luajit21 import LuaRuntime

root = Path(__file__).resolve().parents[1] / 'lua/background_npcs_core'
lua = LuaRuntime()
lua.execute('''
    CLIENT=true; SERVER=false
    bgNPC={Config={GetActor=function() return data end}}
    function istable(v) return type(v)=='table' end
    function IsValid(v) return type(v)=='table' and not v.removed end
    function GetConVar() return {GetBool=function() return enabled end} end
    math.Rand=function() return roll end
    enabled=true; roll=0
    data={carry_items={chance=5,items={'ration','suitcase'}}}
    ent={LookupSequence=function(_,name) return supported[name] and 1 or -1 end}
    supported={idlepackage=true,walk_holding_package_all=true}
''')
lua.execute((root / 'systems/sh_carry_items.lua').read_text(encoding='utf-8-sig').split('if CLIENT then return end', 1)[0])
lua.execute('''
    local C=bgNPC.CarryItems
    assert(C.Roll(ent,'citizen')=='ration', 'models without suitcase sequences only get a supported item')
    roll=5; assert(not C.Roll(ent,'citizen'), '5 percent is a single combined chance, not a chance per item')
    roll=0; enabled=false; assert(not C.Roll(ent,'citizen'), 'the per-type checkbox gates new item selection')
    enabled=true; supported.walk_holding_package_all=false
    assert(not C.Roll(ent,'citizen'), 'an idle-only model cannot become a walking carrier')
    assert(C.Roll(nil,'citizen',nil,{suitcase=true})=='suitcase', 'server ghosts use capabilities sampled from a real model')
    data.carry_items=false; assert(not C.Roll(ent,'police'), 'types without carry config never get props')
    assert(C.items.ration.pocket and not C.items.suitcase.pocket, 'a parcel can be stowed; a suitcase must be dropped')
''')
print('PASS: carry chance, model eligibility, per-type setting and server-ghost selection')
