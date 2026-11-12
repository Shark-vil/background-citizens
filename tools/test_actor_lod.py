"""Staggered actor simulation regression: python tools/test_actor_lod.py (lupa)."""
from pathlib import Path
from lupa.luajit21 import LuaRuntime
lua=LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
now=0; cv={}; hooks={}
FCVAR_ARCHIVE=1
function CurTime() return now end
function IsValid(v) return type(v)=='table' and v.valid end
function CreateConVar(n,d) if not cv[n] then cv[n]={value=tonumber(d),GetFloat=function(self) return self.value end} end return cv[n] end
function GetConVar(n) return CreateConVar(n,500) end
hook={Add=function(n,id,f) hooks[n]=f end,Run=function() end}
bgNPC={Actors={Get=function(n) return n.actor end},Tasks={Add=function() end},Util={IsInView=function() return seen end},Points={}}
function Actor(uid)
 local a={uid=uid,start_think=true,moves=0,brains=0,flips=0,distance=10000,alive=true}
 a.npc={valid=true,actor=a}
 function a:GetNPC() return self.npc end
 function a:GetPos() return {DistToSqr=function() return self.distance^2 end} end
 function a:HasState() return false end
 function a:InVehicle() return self.vehicle end
 function a:HasActiveWeapon() return self.armed end
 function a:EnemiesRecalculate() end
 function a:RecalculationTargets() end
 function a:UpdateMovement() self.moves=self.moves+1 end
 a.body={SetThinkEnabled=function(_,on) a.on=on a.flips=a.flips+1 end}
 a.brain={Update=function() a.brains=a.brains+1 end}
 return a
end
players={{valid=true,GetPos=function() return {} end}}
''')
source=(Path(__file__).resolve().parents[1]/'lua/background_npcs_core/actor/update/sv_actor_update.lua').read_text(encoding='utf-8-sig')
update,compute=lua.execute(source+'\nreturn UpdateActor, ComputeLOD')
lua.globals().update=update
lua.execute('''
a=Actor(1); b=Actor(2)
now=.3; update(a,now,players); update(b,now,players)
assert(a.on and not b.on,'successive UIDs have different phases')
local before=b.brains; update(b,now,players); assert(b.brains==before,'no brain during pause')
for n=1,600 do now=n*.1 update(a,now,players) update(b,now,players) end
assert(a.moves>100 and b.moves>100 and a.flips>20 and b.flips>20,'both actors repeatedly resume')
now=1.5; a.next_lod=0; update(a,now,players); assert(not a.on)
bgNPC.Actors.WakeUp(a); assert(a.on and a.next_lod==now+1)
now=1.6; update(a,now,players); assert(a.on,'event wake survives next scheduler pass')
seen=true; now=3; a.next_lod=0; update(a,now,players); assert(a.on and a.lod==1)
seen=false; a.distance=10; a.next_lod=0; update(a,now,players); assert(a.on and a.lod==1)
a.distance=10000; a.armed=true; a.next_lod=0; update(a,now,players); assert(a.on and a.lod==2)
a.armed=false; a.vehicle=true; a.next_lod=0; update(a,now,players); assert(a.on)
a.vehicle=false; cv.bgn_logic_pause.value=0; a.next_lod=0; now=1.5; update(a,now,players); assert(a.on)
cv.bgn_logic_pause.value=2; cv.bgn_logic_active.value=.5; cv.bgn_logic_stagger.value=0
now=.25; a.next_lod=0; b.next_lod=0; update(a,now,players); update(b,now,players); assert(a.on and b.on)
now=.75; update(a,now,players); update(b,now,players); assert(not a.on and not b.on)
a.body={SetThinkEnabled=function(_,on) replacement_on=on end}
update(a,now,players); assert(replacement_on==false,'new body inherits the current pause')

''')
print('PASS: repeated work windows, stagger, pause gating, immediate wake, eligibility and live settings')
