-- Opt-in SP gm_bigcity_improved pose/placement fixture. Uses normal model hooks and real brush traces.
assert(game.SinglePlayer() and game.GetMap() == 'gm_bigcity_improved' and not BGNPosesLab, 'isolated idle SP lab required')
local ply, S = player.GetHumans()[1], bgNPC.Scenic.Spots
local old_body = GetConVar('bgn_actor_body'):GetString()
local old_enable = GetConVar('bgn_enable'):GetString()
GetConVar('bgn_enable'):SetString('1')
local old_pos, old_ang, old_move = ply:GetPos(), ply:EyeAngles(), ply:GetMoveType()
local base = assert(S.Floor(Vector(-800, 1000, -11140)))
local room = Vector(-160, 2910, -9343.9688)
local report, item, support = { cases = {}, errors = {} }
BGNPosesLab = report
local job, model_index = nil, 0
local male, female = 'models/humans/group01/male_07.mdl', 'models/humans/group01/female_07.mdl'
hook.Add('BGN_OverrideSpawnData', 'BGN_PosesLab', function(kind, data)
	if kind ~= 'citizen' then return end
	model_index = model_index + 1
	data = table.Copy(data)
	data.models = { job.partial and model_index == 2 and 'models/player/group01/male_01.mdl' or (job.female and female or male) }
	data.random_model, data.default_models = false, false
	return data
end)
local function Write()
	file.CreateDir('bgn_scenic_overhaul_lab')
	file.Write('bgn_scenic_overhaul_lab/poses.json', util.TableToJSON(report, true))
end
local function Clear()
	if item then
		for _, actor in ipairs(item.actors) do
			if actor:IsAlive() then actor:SetState('none', nil, true) end
			actor:Remove()
		end
		bgNPC.Scenic.Remove(item) item = nil
	end
	if IsValid(support) then support:Remove() end
end
local function Finish()
	Clear() hook.Remove('BGN_OverrideSpawnData', 'BGN_PosesLab')
	GetConVar('bgn_actor_body'):SetString(old_body)
	GetConVar('bgn_enable'):SetString(old_enable)
	ply:SetPos(old_pos) ply:SetEyeAngles(old_ang) ply:SetMoveType(old_move)
	report.done, report.passed = true, #report.errors == 0 Write() BGNPosesLab = nil
end
local function Protect(fn)
	if not BGNPosesLab then return end
	local ok, err = xpcall(fn, debug.traceback)
	if not ok then report.errors[#report.errors + 1] = err Finish() end
end
local function Wall(scene)
	for _, dir in ipairs({ Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0) }) do
		local from = room + Vector(0, 0, 36)
		local tr = util.TraceLine({ start = from, endpos = from + dir * 500, mask = MASK_SOLID_BRUSHONLY })
		if tr.Hit and tr.HitWorld and math.abs(tr.HitNormal.z) < 0.1 then
			local spot = S.Find('wall', tr.HitPos + tr.HitNormal * 35, scene)
			if spot then return spot end
		end
	end
end
local jobs = {}
for _, body in ipairs({ 'npc', 'nextbot' }) do
	for _, id in ipairs({ 'plaza', 'interrogation', 'arrest_wall', 'tired_wall', 'door_brace', 'radio_operator' }) do jobs[#jobs + 1] = { body = body, id = id } end
	for _, id in ipairs({ 'couch_couple', 'couch_lying' }) do
		jobs[#jobs + 1] = { body = body, id = id }
		jobs[#jobs + 1] = { body = body, id = id, female = true }
	end
	for _, seq in ipairs({ 'sit_ground', 'sitcouchfeet1', 'sitcouchknees1' }) do jobs[#jobs + 1] = { body = body, id = 'ground_sit', seq = seq } end
	for _, seq in ipairs({ 'd2_coast03_postbattle_idle02', 'LineIdle01', 'idle_subtle' }) do jobs[#jobs + 1] = { body = body, id = 'tired', seq = seq } end
	jobs[#jobs + 1] = { body = body, id = 'ledge_sitting' }
	jobs[#jobs + 1] = { body = body, id = 'couch_couple', partial = true }
end
local index, Next = 0
Next = function()
	Clear() index = index + 1 job = jobs[index]
	if not job then Finish() return end
	model_index = 0
	GetConVar('bgn_actor_body'):SetString(job.body)
	local scene = table.Copy(bgNPC.cfg.scenic[job.id])
	if job.seq then scene.members[1].seq = job.seq end
	local spot
	if scene.indoors then
		assert(not S.Find('floor', base, scene), 'indoor scenes must reject the outdoor test area')
		spot = { pos = room, ang = Angle() }
	elseif scene.place == 'wall' then spot = assert(Wall(scene), 'room has a usable wall')
	elseif scene.place == 'door' then
		support = ents.Create('prop_door_rotating') support:SetModel('models/props_c17/door01_left.mdl')
		support:SetPos(base + Vector(0, 0, 54.25)) support:Spawn()
		spot = assert(S.Find('door', support, scene))
	elseif scene.place == 'ledge' then
		-- Clone a box brush from this map as a harmless temporary raised platform (no map edits).
		support = ents.Create('func_brush') support:SetModel('*1') support:SetPos(base + Vector(0, 0, -85)) support:Spawn()
		support:SetSolid(SOLID_BSP)
		spot = assert(S.Find('ledge', base + Vector(0, 80, 40), scene), 'real brush lip is detected')
	else spot = assert(S.Find('floor', base, scene)) end
	ply:SetMoveType(MOVETYPE_NOCLIP) ply:SetPos(spot.pos + Vector(240, 200, 25))
	ply:SetEyeAngles((spot.pos + Vector(0, 0, 35) - ply:EyePos()):Angle())
	local plan = assert(bgNPC.Scenic.Plan(scene, spot), job.id .. ': valid placement plan')
	item = assert(bgNPC.Scenic.Create(job.id, scene, spot, plan, ply), job.id .. ': ordinary actor creation')
	for _, actor in ipairs(item.actors) do actor.data.at_random = nil actor.scenic_debug_item = item end
	timer.Simple(0.6, function() Protect(function()
		if job.partial then
			assert(item.removed and #item.failures > 0, 'incompatible pair cancels completely')
			for _, actor in ipairs(item.actors) do assert(not actor:IsAlive(), 'no isolated partner remains') end
		else
			assert(not item.removed and #item.failures == 0, job.id .. ': supported scene starts as a whole')
			for i, actor in ipairs(item.actors) do
				local npc = actor:GetNPC()
				assert(actor:IsAlive() and actor:HasState('scenic_npc') and actor:IsAnimationPlayed(), job.id .. ': stable pose member '
					.. i .. ', state=' .. actor:GetState() .. ', health=' .. actor:Health() .. ', animated=' .. tostring(actor:IsAnimationPlayed())
					.. ', pos=' .. (IsValid(npc) and tostring(npc:GetPos()) or 'removed'))
				assert(npc:GetClass() == (job.body == 'npc' and (i == 2 and scene.members[i].type == 'police' and 'npc_metropolice' or 'npc_citizen') or 'bgn_nextbot'), 'requested body')
				if job.id == 'interrogation' then assert(npc:SequenceDuration(npc:GetSequence()) > 1, 'interrogation uses a live sequence') end
				if job.id == 'arrest_wall' and i == 1 then
					local plane = spot.pos - spot.ang:Forward() * scene.gap
					local hand = npc:GetBonePosition(npc:LookupBone('ValveBiped.Bip01_L_Hand'))
					local distance = math.abs((hand - plane):Dot(spot.ang:Forward()))
					assert(distance < 8, 'searching citizen hands reach the wall: ' .. distance)
				end
				if job.id == 'door_brace' then
					local normal = spot.ang:Forward()
					local center = support:LocalToWorld(support:OBBCenter())
					local hand = npc:GetBonePosition(npc:LookupBone('ValveBiped.Bip01_R_Hand'))
					assert(math.abs((hand - center):Dot(normal)) < 12, 'bracing hands reach the door')
				end
				actor:SetState('none', nil, true)
				assert(npc:GetPos():Distance(plan.members[i].stand) < 1, 'pose exits to safe standing height')
			end
		end
		report.cases[#report.cases + 1] = { name = job.body .. '_' .. job.id .. (job.seq and '_' .. job.seq or '')
			.. (job.female and '_female' or '') .. (job.partial and '_partial_model' or ''), passed = true }
		Write() timer.Simple(0.1, function() Protect(Next) end)
	end) end)
end
Protect(Next)
return { pending = true, report = 'bgn_scenic_overhaul_lab/poses.json' }
