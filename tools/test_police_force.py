"""Witness-local police force and NextBot pistol cadence: python tools/test_police_force.py (lupa)."""
from pathlib import Path
from lupa.luajit21 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
lua.execute('''
hooks={}; now=0; counts={}; wanted={}; observers={}; seen=true
function IsValid(e) return type(e)=='table' and e.valid==true end
function CurTime() return now end
hook={Add=function(n,id,f) hooks[n]=f end}
bgNPC={Combat={},Actors={},Statistics={},Modules={},Vision={}}
function bgNPC.Statistics.GetSum(e) return counts[e] or 0 end
function bgNPC.Statistics.Reset(e) counts[e]=nil end
function bgNPC.Modules.Get() return {HasWanted=function(_,e) return wanted[e] end} end
function bgNPC.Actors.Get(e) return e and e.actor end
function bgNPC.Actors.GetAll() return observers end
function bgNPC.Actors.GetInRadius() return observers end
function bgNPC.Vision.HasLineOfSight() return seen end
function bgNPC.Combat.CanWitness() return seen end
function bgNPC.Combat.IsAttackingEnemy() return false end
function bgNPC.Combat.ResolveVehicleAttacker(e) return e end
function bgNPC.Combat.IsAttacker(e) return IsValid(e) end
ents={GetAll=function() return {} end}
function Entity(x) return {valid=true,health=100,x=x or 0,Health=function(self) return self.health end,
 GetPos=function(self) return {x=self.x,DistToSqr=function(p,o) return (p.x-o.x)^2 end} end,
 IsPlayer=function() return false end,IsNPC=function() return true end,IsNextBot=function() return false end} end
suspect=Entity()
function Actor(uid,police)
 local a={uid=uid,police=police,npc=Entity()}; a.npc.actor=a
 function a:GetNPC() return self.npc end
 function a:GetMaxHealth() return 100 end
 function a:IsAlive() return true end
 function a:HasTeam(other) if type(other)=='string' then return other=='police' and self.police end return other~=suspect end
 return a
end
officer=Actor(1,true); observers={officer}
dmg={GetDamage=function() return 1 end,GetAttacker=function() return suspect end}
''')
lua.execute((ROOT/'lua/background_npcs_core/api/sv_police_force.lua').read_text(encoding='utf-8-sig'))
lua.execute('''
local C=bgNPC.Combat
assert(C.CanPoliceUseStunstick(officer,suspect))
local victim=Actor(2,false)
seen=false; hooks.PostEntityTakeDamage(victim.npc,dmg,true); assert(not officer.police_harm)
seen=true; hooks.PostEntityTakeDamage(victim.npc,dmg,false); assert(not officer.police_harm)
hooks.PostEntityTakeDamage(victim.npc,dmg,true); hooks.PostEntityTakeDamage(victim.npc,dmg,true)
assert(officer.police_harm[suspect].count==1,'repeat hits do not count new victims')
for uid=3,6 do hooks.PostEntityTakeDamage(Actor(uid,false).npc,dmg,true) end
assert(C.CanPoliceUseStunstick(officer,suspect),'exactly five victims still permit baton')
hooks.PostEntityTakeDamage(Actor(7,false).npc,dmg,true)
assert(not C.CanPoliceUseStunstick(officer,suspect),'six distinct victims forbid baton')
C.ResetPoliceThreat(suspect); assert(C.CanPoliceUseStunstick(officer,suspect))
victim.npc.health=31; hooks.PostEntityTakeDamage(victim.npc,dmg,true); assert(C.CanPoliceUseStunstick(officer,suspect))
victim.npc.health=30; hooks.PostEntityTakeDamage(victim.npc,dmg,true); assert(not C.CanPoliceUseStunstick(officer,suspect))
victim.npc.health=100; assert(not C.CanPoliceUseStunstick(officer,suspect),'serious injury remembered until reset')
C.ResetPoliceThreat(suspect)
victim.npc.health=30; hooks.BGN_PostVehicleDamage(victim,suspect,1)
assert(not C.CanPoliceUseStunstick(officer,suspect),'virtual vehicle damage is counted')
local replacement=Entity(); hooks.BGN_ActorEntityChanged(nil,suspect,replacement)
assert(not officer.police_harm[suspect] and officer.police_harm[replacement])
local old=suspect; suspect=replacement; old.valid=false; hooks.EntityRemoved(old)
assert(not C.CanPoliceUseStunstick(officer,suspect),'old body removal preserves rebound history')
wanted[suspect]=true; hooks.BGN_RemoveWantedTarget(suspect); assert(not C.CanPoliceUseStunstick(officer,suspect))
wanted[suspect]=nil; assert(C.CanPoliceUseStunstick(officer,suspect))
for _,event in ipairs({'PlayerDeath','PlayerSilentDeath','OnNPCKilled','BGN_RemoveWantedTarget','EntityRemoved'}) do
 hooks.PostEntityTakeDamage(victim.npc,dmg,true)
 counts[suspect]=2; suspect.bgn_has_killed=true
 assert(not C.CanPoliceUseStunstick(officer,suspect))
 hooks[event](suspect)
 assert(counts[suspect]==nil and suspect.bgn_has_killed==nil and not officer.police_harm[suspect],event)
end
-- A bystander that did not see the hit does not inherit another officer's count.
local second=Actor(8,true); observers={second}; seen=false
hooks.PostEntityTakeDamage(victim.npc,dmg,true); assert(not second.police_harm)
''')
lua.execute('seen=true; reload_victim=Actor(10,false); hooks.PostEntityTakeDamage(reload_victim.npc,dmg,true)')
lua.execute((ROOT/'lua/background_npcs_core/api/sv_police_force.lua').read_text(encoding='utf-8-sig'))
lua.execute('bgNPC.Combat.ResetPoliceThreat(suspect); assert(not observers[1].police_harm[suspect])')
print('PASS: distinct witnessed victims, five/six and 30% boundaries, sticky injury, rebind and all reset events')
lua.execute('''
local C=bgNPC.Combat
local cop,thug,sniper,near=Actor(20,true),Entity(),Entity(600),Entity(400)
observers={}
local hit=function(attacker) return {GetDamage=function() return 1 end,GetAttacker=function() return attacker end} end
hooks.PostEntityTakeDamage(Actor(21,false).npc,hit(near),true)
assert(not near.bgn_ranged_attack,'a hit from 400 units is not ranged')
hooks.PostEntityTakeDamage(Actor(22,false).npc,hit(sniper),false)
assert(not sniper.bgn_ranged_attack,'a blocked hit marks nobody')
hooks.PostEntityTakeDamage(Actor(23,false).npc,hit(sniper),true)
assert(sniper.bgn_ranged_attack,'a hit from 600 units is ranged')
cop.enemies={thug}
assert(C.CanPoliceUseStunstick(cop,thug),'a melee enemy alone allows the baton')
cop.enemies={thug,sniper}
assert(not C.CanPoliceUseStunstick(cop,thug),'a ranged shooter among the enemies forbids the baton')
assert(not C.CanPoliceUseStunstick(Actor(24,true),sniper),'the shooter itself is never batoned')
C.ResetPoliceThreat(sniper)
assert(C.CanPoliceUseStunstick(cop,thug),'a reset shooter no longer forbids it')
''')
print('PASS: an enemy that hit from farther than 500 units forbids the stunstick until reset')

burst=LuaRuntime()
burst.execute('''
now=0; shots={}; ENT={}; ACTIVITIES={pistol={}}; PROFICIENCY={[0]={spread=1,damage=1}}; WEAPON_PROFICIENCY_AVERAGE=0
function CurTime() return now end
function IsValid() return false end
math.Rand=function(a,b) return (a+b)/2 end
local pick=0; math.random=function(a,b) pick=pick%3+1 return math.min(b,math.max(a,pick)) end
local v={}; v.__index=v; function v:GetNormalized() return self end
function v.__sub() return setmetatable({},v) end
function Vector() return setmetatable({},v) end
bot=setmetatable({clip=18,proficiency=0},{__index=ENT})
function bot:BGN_Hand() end
function bot:BGN_EyePos() return Vector() end
function bot:FireBullets(b) shots[#shots+1]={time=now,num=b.Num} end
function bot:RestartGesture() end
enemy={IsPlayer=function() return false end,WorldSpaceCenter=function() return Vector() end}
''')
source=(ROOT/'lua/entities/bgn_nextbot.lua').read_text(encoding='utf-8-sig')
stats=source[source.index('local WEAPONS ='):source.index('local DEFAULT_WEAPON')]
burst.execute('function table.Copy(t) local c={} for k,v in pairs(t) do c[k]=v end return c end')
defaults=source[source.index('local DEFAULT_WEAPON'):].split('\n',2)[:2]
burst.execute(stats+'\n'+'\n'.join(defaults)+"\nassert(DEFAULT_WEAPON.burst_max==nil); stats=WEAPONS.weapon_pistol")
a=source.index('function ENT:Attack('); b=source.index('-- Keeps the body turned',a)
burst.execute(source[a:b])
burst.execute('''
for tick=0,1500 do now=tick/100 if now>=(bot.next_fire or 0) then bot:Attack(enemy,stats) end end
local short,long,reload=false,false,false
for i=2,#shots do
 local gap=shots[i].time-shots[i-1].time
 assert(shots[i].num==1,'burst bullets are separate shots')
 if gap<.3 then short=true end
 if gap>=.45 and gap<1 then long=true end
 if gap>=1.8-.001 then reload=true end
end
assert(short and long and reload,'single/rapid shots, rests and magazine reload all exist')
''')
print('PASS: pistol separate rapid shots, inter-burst rests and magazine reload')
for path in ('api/sv_police_force.lua','api/sv_combat.lua','systems/wanted/sh_wanted_class.lua','brain/fsm/states/sv_arrest.lua'):
 lua.execute('assert(loadstring(...))',(ROOT/'lua/background_npcs_core'/path).read_text(encoding='utf-8-sig'))
