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
    ent={IsNPC=function() return native end,LookupBone=function() if not hand_missing then return 1 end end,
        LookupSequence=function(_,name) return supported[name] and 1 or -1 end}
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
    data={carry_items={chance=5,items={'ration','suitcase','newspaper'}}}
    native=true
    assert(C.Roll(ent,'citizen')=='suitcase', 'HL2 NPCs only select the clientside briefcase, without carry sequences')
    hand_missing=true; assert(not C.Supports(ent,'suitcase'), 'a briefcase requires a valid hand bone'); hand_missing=false
    assert(not C.Supports(ent,'ration') and not C.Supports(ent,'newspaper'), 'two-handed carry never changes native NPC locomotion')
    supported.idlepackage=true; supported.walk_holding_package_all=true
    assert(C.Supports(ent,'newspaper',true), 'ghost capability sampling still accepts two-handed visuals from NPC rigs')
    assert(C.items.newspaper.weapon==C.items.ration.weapon and C.items.newspaper.model~=C.items.ration.model,
        'newspapers use the parcel pose with a different visible model')
''')
source = (root / 'systems/sh_carry_items.lua').read_text(encoding='utf-8-sig')
compatible = lua.execute(source[source.index('local function Compatible(actor)'):source.index('function Carry.Remove(actor, drop)')] + '\nreturn Compatible')
lua.globals().compatible = compatible
lua.execute('''
    local npc={IsBGNNextBot=true,move_run=false}
    local a={GetState=function() return 'walk' end,GetNPC=function() return npc end,
        InVehicle=function() return false end,IsAnimationPlayed=function() return false end,HasActiveWeapon=function() return false end}
    assert(compatible(a), 'NextBot walking keeps the carrying pose')
    npc.move_run=true; assert(not compatible(a), 'unsupported NextBot running stows or drops its carried item')
    npc.IsBGNNextBot=false; assert(compatible(a), 'HL2 briefcase does not constrain normal locomotion')
''')
lua.execute('''
    now=0; native=true; hand_missing=false
    function CurTime() return now end
    hook={Add=function(_,_,fn) visual_think=fn end}
    local npc=ent
    visual_actor={carry_visual='suitcase',GetNPC=function() return npc end,IsAlive=function(self) return not self.dead end}
    bgNPC.Actors={GetAll=function() return {visual_actor} end}
    bgNPC.CarryItems.CreateVisual=function(parent,kind,is_native)
        assert(is_native and kind=='suitcase', 'HL2 visual uses the clientside briefcase path')
        return {GetParent=function() return parent end,Remove=function(self) self.removed=true end}
    end
''')
lua.execute((root / 'systems/cl_carry_items.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
    local C=bgNPC.CarryItems
    visual_think(); local first=assert(C.visuals[visual_actor])
    now=1; visual_actor.carry_visual=nil; visual_think()
    assert(first.removed and not C.visuals[visual_actor], 'a stowed/removed snapshot clears the client prop')
    now=2; visual_actor.carry_visual='suitcase'; visual_think(); local second=C.visuals[visual_actor]
    now=3; second.removed=true; visual_think()
    assert(C.visuals[visual_actor]~=second, 'an externally removed client prop is recreated safely')
    now=4; visual_actor.dead=true; local last=C.visuals[visual_actor]; visual_think()
    assert(last.removed and not C.visuals[visual_actor], 'dead actors leave no client props')
''')
print('PASS: carry chance/body eligibility, native briefcase, newspaper, locomotion and client prop lifecycle')
