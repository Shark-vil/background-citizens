-- Opt-in SP test of live actor identity and mutable attributes through a temporary ragdoll.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved' and not BGNIdentityLab, 'isolated idle SP lab required')
local ply, Wanted = player.GetHumans()[1], bgNPC.Modules.Get('wanted')
local old_body = GetConVar('bgn_actor_body'):GetString()
local report, item, observer = { cases = {}, errors = {} }
BGNIdentityLab = report
local base = assert(bgNPC.Scenic.Spots.Floor(Vector(-800, 1000, -11140)))
local function Clear()
	if item then
		local npc = item.actors[1]:GetNPC()
		Wanted:RemoveWanted(npc)
		bgNPC.Scenic.Debug.Remove(ply, item) item = nil
	end
	if IsValid(observer) then observer:Remove() end
	timer.Remove('BGN_IdentityLab')
end
local function Write()
	file.CreateDir('bgn_scenic_overhaul_lab')
	file.Write('bgn_scenic_overhaul_lab/identity.json', util.TableToJSON(report, true))
end
local function Finish()
	Clear() GetConVar('bgn_actor_body'):SetString(old_body)
	report.done, report.passed = true, #report.errors == 0
	Write() BGNIdentityLab = nil
end
local function Protect(fn)
	if not BGNIdentityLab then return end
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then report.errors[#report.errors + 1] = err Finish() end
end
local index, Next = 0
Next = function()
	Clear() index = index + 1
	local body_name = ({ 'npc', 'nextbot' })[index]
	if not body_name then Finish() return end
	GetConVar('bgn_actor_body'):SetString(body_name)
	item = assert(bgNPC.Scenic.Debug.Spawn(ply, 'plaza', { Hit = true, HitPos = base, HitNormal = Vector(0, 0, 1) }))
	local actor = item.actors[1]
	actor.data.at_random, actor.data.regeneration = nil, false
	actor.mechanics.use_vehicle, actor.mechanics.call_for_help = false, false
	timer.Simple(0.5, function() Protect(function()
		local npc, uid, body = actor:GetNPC(), actor.uid, actor:GetBody()
		npc:SetMaxHealth(90) npc:SetHealth(70)
		actor.weapon = 'weapon_pistol'
		actor:SetState('none', nil, true)
		actor:PrepareWeapon('weapon_pistol', true)
		local weapon = actor:GetActiveWeapon()
		assert(IsValid(weapon), 'test weapon is equipped')
		weapon:SetClip1(5)
		if npc.IsBGNNextBot then npc.clip = 4 end
		observer = ents.Create('npc_combine_s') observer:SetPos(base + Vector(250, 150, 4)) observer:Spawn()
		observer:SetNPCState(NPC_STATE_SCRIPT) observer:SetSchedule(SCHED_NPC_FREEZE)
		actor:AddEnemy(observer, nil, true)
		body:SetDisposition(observer, D_FR)
		observer:AddEntityRelationship(npc, D_HT, 99)
		local wanted = assert(Wanted:AddWanted(npc, 25)) wanted:SetLevel(2)
		assert(actor:SetState('knocked_down', { velocity = vector_origin, resume = 'none' }, true))
		local rag = actor:GetStateData().ragdoll
		timer.Simple(0.5, function() Protect(function()
			local damage = DamageInfo() damage:SetDamage(5) damage:SetDamageType(DMG_BULLET)
			damage:SetAttacker(game.GetWorld()) damage:SetInflictor(game.GetWorld())
			rag:TakeDamageInfo(damage)
			weapon:SetClip1(3)
			if npc.IsBGNNextBot then npc.clip = 2 end
			wanted:SetLevel(3)
		end) end)
		local deadline = CurTime() + 7
		timer.Create('BGN_IdentityLab', 0.1, 0, function() Protect(function()
			assert(CurTime() < deadline, 'actor must safely recover')
			if actor:HasState('knocked_down') or IsValid(rag) then return end
			assert(actor:IsAlive() and actor:GetNPC() == npc and actor:GetBody() == body and actor.uid == uid, 'same actor, entity and body adapter')
			assert(actor:Health() == 65 and actor:GetMaxHealth() == 90, 'latest health and maximum health survive')
			assert(actor:GetActiveWeapon() == weapon and weapon:Clip1() == 3, 'same weapon with latest clip survives')
			assert(not npc.IsBGNNextBot or npc.clip == 2, 'NextBot simulated ammunition survives')
			assert(body:GetDisposition(observer) == D_FR and observer:Disposition(npc) == D_HT, 'both outgoing and incoming relationships survive')
			assert(actor:HasEnemy(observer), 'logical enemy references survive')
			assert(Wanted:GetWanted(npc) == wanted and wanted.target == npc and wanted.level == 3, 'latest wanted object/level survives without rebinding')
			assert(not IsValid(rag), 'temporary ragdoll is cleaned up')
			report.cases[#report.cases + 1] = { name = body_name, passed = true }
			Write() Next()
		end) end)
	end) end)
end
Protect(Next)
return { pending = true, report = 'bgn_scenic_overhaul_lab/identity.json' }
