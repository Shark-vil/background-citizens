assert(game.GetMap() == 'gm_bigcity_improved')
local report, cars, actors, providers = {running=true,checks={}}, {}, {}, {}
local wanted_timer='BGN_Timer_CheckingTheWantesStatusOfTargets'
local wanted_paused=timer.IsPaused(wanted_timer)
timer.Pause(wanted_timer)
local function Check(ok,label) assert(ok,label); report.checks[#report.checks+1]=label end
local function Wait(seconds) coroutine.yield(seconds) end
local routine=coroutine.create(function()
    local road=DecentVehicleDestination.Waypoints[1].Target
    local car=bgNPC:SpawnVehicle('simfphys_gta_sa_sultan',road+Vector(0,0,50),Angle())
    assert(IsValid(car)); cars[1]=car; Wait(1)
    car:GetPhysicsObject():EnableMotion(false)
    local provider=BGN_VEHICLE:Instance(car,'residents|npc_decentvehicle|default|1','citizen')
    providers[1]=provider; BGN_VEHICLE:AddToList(provider)
    local npc=ents.Create('npc_citizen'); npc:SetPos(road+Vector(180,0,5)); npc:Spawn()
    local a=bgNPC.Actor.Create(npc,'citizen'); actors[1]=a
    a.data.start_random_state,a.data.start_state,a.data.at_random=false,nil,false
    a.mechanics.movement_controller,a.mechanics.enemies_controller,a.mechanics.targets_controller=false,false,false
    a.eternal=true; Wait(.1); a.start_think=false
    npc.bgn_has_killed,npc.bgn_last_attack=true,CurTime()
    local wanted=bgNPC.Modules.Get('wanted')
    local record=wanted:AddWanted(npc,90); record:SetLevel(3)
    bgNPC.Statistics.AddKill(npc,a)
    local wanted_time=record.time_reset
    a:EnterVehicle(car); Wait(.7)
    Check(a:InVehicle() and not IsValid(npc),'driver boarded')
    Check(wanted:GetWanted(a:GetNPC())==record and record.level==3 and record.time_reset==wanted_time,'wanted record and deadline retained')
    report.kill_flag=a:GetNPC().bgn_has_killed; report.kills=bgNPC.Statistics.GetSum(a:GetNPC())
    Check(a:GetNPC().bgn_has_killed and bgNPC.Statistics.GetSum(a:GetNPC())==1,'kill history follows the actor')
    provider:GetVehicleAI():Remove(); Wait(.2)
    Check(a:IsAlive() and not a:InVehicle() and IsValid(a:GetNPC()),'lost DV controller restores physical body')
    Check(bgNPC.Actors.GetByUid(a.uid)==a and wanted:GetWanted(a:GetNPC())==record,'controller failure retains identity and wanted record')
    local original=provider.Initialize
    provider.Initialize=function() end
    local body=a:GetNPC()
    a:EnterVehicle(car); Wait(.7)
    provider.Initialize=original
    Check(not a:InVehicle() and IsValid(body) and a:GetNPC()==body and not provider.driver,'failed controller creation preserves original body')
    a:EnterVehicle(car); Wait(.7)
    Check(a:InVehicle(),'boarding works after controller failure')
    local spare=ents.Create('bgn_nextbot'); spare.bgn_npc_class='npc_citizen'; spare:SetPos(road+Vector(160,180,5)); spare:Spawn()
    local b=bgNPC.Actor.Create(spare,'citizen'); actors[2]=b
    b.data.start_random_state,b.data.start_state,b.data.at_random=false,nil,false
    b.eternal=true; Wait(.1); b.start_think=false
    b:EnterVehicle(car); Wait(.7)
    Check(not b:InVehicle() and IsValid(spare),'full vehicle preserves waiting NextBot body')
    provider:Remove(); Wait(.1)
    Check(a.is_removed and not bgNPC.Actors.GetByUid(a.uid) and not IsValid(a:GetNPC()),'provider removal deletes seated actor')
    Check(b:IsAlive() and b:GetNPC()==spare,'car removal leaves an unboarded actor intact')
    report.passed=true
end)
local function Resume()
    local ok,delay=coroutine.resume(routine)
    if not ok then report.passed=false; report.error=debug.traceback(routine,tostring(delay)) end
    if not ok or coroutine.status(routine)=='dead' then
        report.running=false
        for _,a in ipairs(actors) do a:Remove() end
        for _,p in ipairs(providers) do p:Remove(); BGN_VEHICLE:RemoveFromList(p) end
        for _,c in ipairs(cars) do if IsValid(c) then c:Remove() end end
        if not wanted_paused then timer.UnPause(wanted_timer) end
        file.Write('bgn_dv_lab/lifecycle_guards.json',util.TableToJSON(report,true))
    else timer.Simple(delay,Resume) end
end
Resume()
return {running=true}
