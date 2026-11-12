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
    data={carry_items={chance=5,items={'ration'}}}
    ent={IsNPC=function() return native end,LookupBone=function() if not hand_missing then return 1 end end,
        LookupSequence=function(_,name) return supported[name] and 1 or -1 end}
    supported={idlepackage=true,walk_holding_package_all=true}
''')
lua.execute((root / 'systems/sh_carry_items.lua').read_text(encoding='utf-8-sig').split('if CLIENT then return end', 1)[0])
lua.execute('''
    local C=bgNPC.CarryItems
    assert(C.Roll(ent,'citizen')=='ration', 'a parcel requires both carrying sequences')
    roll=5; assert(not C.Roll(ent,'citizen'), '5 percent is a single combined chance, not a chance per item')
    roll=0; enabled=false; assert(not C.Roll(ent,'citizen'), 'the per-type checkbox gates new item selection')
    enabled=true; supported.walk_holding_package_all=false
    assert(not C.Roll(ent,'citizen'), 'an idle-only model cannot become a walking carrier')
    data.carry_items=false; assert(not C.Roll(ent,'police'), 'types without carry config never get props')
    assert(C.items.ration.pocket and not C.items.suitcase.pocket, 'a parcel can be stowed; a suitcase has a separate lifetime')
    data={carry_items={chance=5,items={'ration','suitcase','newspaper'}}}
    native=false; supported={}
    assert(C.Supports(ent,'suitcase'), 'NextBot briefcase needs a hand, not luggage sequences')
    assert(not C.Drop('suitcase',{}), 'briefcases never create dropped entities')
    native=true
    assert(C.Roll(ent,'citizen')=='suitcase', 'HL2 NPCs only select the clientside briefcase, without carry sequences')
    hand_missing=true; assert(not C.Supports(ent,'suitcase'), 'a briefcase requires a valid hand bone'); hand_missing=false
    assert(not C.Supports(ent,'ration') and not C.Supports(ent,'newspaper'), 'two-handed carry never changes native NPC locomotion')
    supported.idlepackage=true; supported.walk_holding_package_all=true
    assert(C.items.newspaper.weapon==C.items.ration.weapon and C.items.newspaper.model~=C.items.ration.model,
        'newspapers use the parcel pose with a different visible model')
''')
source = (root / 'systems/sh_carry_items.lua').read_text(encoding='utf-8-sig')
compatible = lua.execute(source[source.index('local function CombatState(actor, state)'):source.index('function Carry.Remove(actor, drop)')] + '\nreturn Compatible')
lua.globals().compatible = compatible
lua.execute('''
    local npc={IsBGNNextBot=true,move_run=false}
    local a={GetState=function() return 'walk' end,GetNPC=function() return npc end,
        InVehicle=function() return false end,IsAnimationPlayed=function() return false end,HasActiveWeapon=function() return false end}
    assert(compatible(a), 'NextBot walking keeps the carrying pose')
    npc.move_run=true; assert(not compatible(a), 'unsupported NextBot running stows or drops its carried item')
    npc.IsBGNNextBot=false; assert(compatible(a), 'HL2 locomotion is unaffected')
    a.carry_item='suitcase'
    a.HasStateGroup=function(_,state) return state=='defense' end
    npc.IsBGNNextBot=true
    assert(compatible(a), 'running never discards a briefcase')
    a.GetState=function() return 'random_gesture' end
    assert(compatible(a), 'calm gestures retain the briefcase')
    a.GetState=function() return 'defense' end
    assert(not compatible(a), 'combat removes a briefcase')
    a.GetState=function() return 'retreat' end
    assert(not compatible(a), 'retreat is combat despite its other state group')
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

# Exercise real server lifetime hooks and the Tool's trust boundary.
server = LuaRuntime()
server.execute("""
 CLIENT=false; SERVER=true; bgNPC={CarryItems={active={}}}; hooks={}
 hook={Add=function(event,_,fn) hooks[event]=fn end}; timer={Simple=function() end}
 function IsValid(v) return type(v)=='table' and not v.removed end
 function istable(v) return type(v)=='table' end
""")
server.execute(source[:source.index("hook.Add('Think'")] + source[source.index("hook.Add('BGN_OnKilledActor'"):])
server.execute("""
 local C=bgNPC.CarryItems
 local npc={IsBGNNextBot=true,IsNPC=function() return false end,LookupBone=function() return 1 end,GetPos=function() return {} end}
 actor={state='walk',IsAlive=function() return true end,InVehicle=function() return false end,
  GetNPC=function() return npc end,GetData=function() return {} end,GetState=function(self) return self.state end,
  HasStateGroup=function(_,s) return s=='defense' or s=='fear' or s=='arrest' end}
 C.Drop=function() error('a briefcase must never create a physical prop') end
 assert(C.Attach(actor,'suitcase')); assert(actor.carry_visual=='suitcase')
 for _,state in ipairs({'random_gesture','sit_to_chair','walk','dialogue'}) do
  hooks.BGN_PreSetState(actor,state); assert(actor.carry_item=='suitcase')
 end
 C.Suspend(actor); assert(actor.carry_item=='suitcase')
 for _,state in ipairs({'defense','fear','arrest','retreat'}) do
  assert(C.Attach(actor,'suitcase')); hooks.BGN_PreSetState(actor,state)
  assert(not actor.carry_item and not C.active[actor])
 end
 assert(C.Attach(actor,'suitcase')); hooks.BGN_OnKilledActor(actor); assert(not actor.carry_item)
 TOOL={}; bgNPC.Actors={Get=function(ent) if ent==npc then return actor end end}
 bgNPC.Util={Lang=function(t) return t.default end,Notify=function() end}
 owner={admin=true,IsAdmin=function(self) return self.admin end}
 TOOL.GetOwner=function() return owner end; TOOL.GetClientInfo=function() return selected end
 actor.HasActiveWeapon=function() return false end
 actor.EqualStateGroup=function() return true end
 actor.SetState=function(self,s) self.state=s end
 trace={Entity=npc}; selected='suitcase'
""")
server.execute((root.parents[0] / 'weapons/gmod_tool/stools/bgn_carry_debug.lua').read_text(encoding='utf-8'))
server.execute("""
 assert(TOOL:LeftClick(trace) and actor.carry_initialized and actor.carry_item=='suitcase')
 owner.admin=false; assert(not TOOL:RightClick(trace) and actor.carry_item=='suitcase')
 assert(not TOOL:LeftClick(trace)); owner.admin=true
 selected='invalid'; assert(not TOOL:LeftClick(trace) and actor.carry_item=='suitcase')
 assert(not TOOL:LeftClick({Entity={}}))
 assert(TOOL:RightClick(trace) and not actor.carry_item)
""")
print('PASS: briefcase calm/combat/death lifetime and admin carry Tool validation')

# The real server handoff suppresses carry even if an old ghost payload contains an item.
ghost_source=(root / 'systems/sv_ghost_crowd.lua').read_text(encoding='utf-8')
handoff=ghost_source[ghost_source.index('local function Handoff('):ghost_source.index('-- Nav points near pos')]
lua.execute("""
    ghosts={}; function GroundPos(p) return p end; function Queue() end
    bgNPC.Config.GetTypeLimit=function() return 10 end
    bgNPC.Config.IsTypeActive=function() return true end
    bgNPC.Actors={GetNPCsByType=function() return {} end}
    local npc={SetModel=function() end,SetSkin=function() end,SetBodyGroups=function() end,EntIndex=function() return 1 end}
    handoff_actor={GetNPC=function() return npc end,carry_item='newspaper'}
    bgNPC.SpawnActor=function() return handoff_actor end
    bgNPC.CarryItems.Remove=function(a,drop) assert(not drop); a.carry_item=nil; a.carry_visual=nil end
""")
lua.execute(handoff+"\nassert(Handoff({id=1,look={type='citizen'},carry='newspaper',seg={speed=0}},{}))")
lua.execute("assert(handoff_actor.carry_initialized and not handoff_actor.carry_item and not handoff_actor.carry_visual)")
print('PASS: ghost materialization suppresses carried items')
