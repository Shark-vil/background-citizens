-- Send through a temporary single-player bridge; exercises the real server Tool and Undo command.
assert(game.SinglePlayer() and not BGNScenicToolTest, 'use an idle, isolated single-player session')
assert(game.GetMap() == 'gm_bigcity_improved', 'fixture coordinates require gm_bigcity_improved')
local ply = player.GetHumans()[1]
local tool = assert(ply:GetTool('bgn_scenic_debug'), 'scene Tool must be available')
local old_info, old_body = tool.GetClientInfo, GetConVar('bgn_actor_body'):GetString()
local old_pos, old_ang, old_move = ply:GetPos(), ply:EyeAngles(), ply:GetMoveType()
local report = { cases = {}, errors = {}, started = CurTime() }
BGNScenicToolTest = report
local choice, item, prop, model_mode
local base = Vector(-800, 1000, -11140)
local ground = util.TraceLine({ start = base + Vector(0, 0, 100), endpos = base - Vector(0, 0, 100), mask = MASK_SOLID_BRUSHONLY })
assert(ground.Hit, 'lab floor')
base = ground.HitPos
function tool:GetClientInfo(key) if key == 'scene' then return choice end return old_info(self, key) end

hook.Add('BGN_OverrideSpawnData', 'BGN_ScenicToolTest', function(kind, data)
	if kind ~= 'citizen' then return end
	data = table.Copy(data)
	data.models = { model_mode == 'missing' and 'models/player/group01/male_01.mdl' or 'models/humans/group01/male_07.mdl' }
	data.random_model, data.default_models, data.random_skin, data.random_bodygroups = false, false, false, false
	return data
end)

local function Write()
	file.CreateDir('bgn_scenic_tool_lab')
	file.Write('bgn_scenic_tool_lab/tool.json', util.TableToJSON(report, true))
end
local function Clear()
	if item then bgNPC.Scenic.Debug.Remove(ply, item) end
	if IsValid(prop) then prop:Remove() end
	item, prop = nil, nil
end
local function Finish()
	Clear()
	timer.Remove('BGN_ScenicToolTest')
	tool.GetClientInfo = old_info
	hook.Remove('BGN_OverrideSpawnData', 'BGN_ScenicToolTest')
	GetConVar('bgn_actor_body'):SetString(old_body)
	ply:SetPos(old_pos)
	ply:SetEyeAngles(old_ang)
	ply:SetMoveType(old_move)
	report.done, report.passed = true, #report.errors == 0
	Write()
	BGNScenicToolTest = nil
end
local function Protect(func)
	if not BGNScenicToolTest then return end
	local ok, err = xpcall(func, debug.traceback)
	if not ok then report.errors[#report.errors + 1] = err Finish() end
end

local jobs = {}
for _, body in ipairs({ 'npc', 'nextbot' }) do
	for _, test in ipairs({ 'knock', 'pending_undo', 'chair', 'chair_body_removed', 'missing_model', 'goap' }) do jobs[#jobs + 1] = { body = body, test = test } end
end
local index = 0
local Next
local function Passed(job)
	report.cases[#report.cases + 1] = { name = job.body .. '_' .. job.test, passed = true }
	Write()
	Next()
end

Next = function()
	Clear()
	index = index + 1
	local job = jobs[index]
	if not job then Finish() return end
	GetConVar('bgn_actor_body'):SetString(job.body)
	model_mode = job.test == 'missing_model' and 'missing' or 'normal'
	local chair = job.test == 'chair' or job.test == 'chair_body_removed' or job.test == 'missing_model'
	choice = chair and 'chair_sitting' or (job.test == 'goap' and 'goap_door' or 'door_knock')
	prop = ents.Create(chair and 'prop_physics' or 'prop_door_rotating')
	prop:SetModel(chair and 'models/props_c17/FurnitureChair001a.mdl' or 'models/props_c17/door01_left.mdl')
	prop:SetPos(base + Vector(0, 0, chair and 20 or 54.25))
	prop:SetAngles(Angle())
	if not chair then prop:SetKeyValue('speed', '100') prop:SetKeyValue('returndelay', '-1') end
	prop:Spawn()
	prop:Activate()
	if chair then prop:GetPhysicsObject():EnableMotion(false) end
	ply:SetMoveType(MOVETYPE_NOCLIP)
	ply:SetPos(base + Vector(140, 180, 15))
	ply:SetEyeAngles((prop:WorldSpaceCenter() - ply:EyePos()):Angle())
	local tr = { Hit = true, Entity = prop, HitPos = prop:WorldSpaceCenter(), HitNormal = prop:GetForward() }
	tool.NextSpawn = 0
	assert(tool:LeftClick(tr), job.body .. '/' .. job.test .. ': Tool placement')
	item = tool.LastItem
	assert(item.debug_owner == ply, 'visible placement is owned by the administrator')
	if job.test == 'chair' then
		timer.Simple(0.1, function() Protect(function()
			local actor = item.actors[1]
			if not actor:HasState('sit_to_chair') then actor:SetState('sit_to_chair', nil, true) end
			assert(actor:HasState('sit_to_chair'), 'exercise an old seating state before delayed scene placement')
		end) end)
	end
	if job.test == 'pending_undo' then
		concommand.Run(ply, 'gmod_undo', {})
		timer.Simple(0.5, function() Protect(function()
			assert(item.debug_removed and not item.started and not item.actors[1]:IsAlive(), 'Undo before setup must not leave/restart an actor')
			Passed(job)
		end) end)
		return
	end
	timer.Simple(0.6, function() Protect(function()
		local actor = item.actors[1]
		if job.test == 'missing_model' then
			assert(item.removed and item.failures[1].reason == 'sequence', 'unsupported model must be diagnosed')
			assert(item.failures[1].model:lower() == 'models/player/group01/male_01.mdl' and not prop.occupied,
				'no model replacement or stuck chair reservation: ' .. item.failures[1].model .. ', occupied=' .. tostring(prop.occupied))
			tool:Report()
			assert(tool:Reload())
			Passed(job)
			return
		end
		local npc = actor:GetNPC()
		assert(npc:GetClass() == (job.body == 'nextbot' and 'bgn_nextbot' or (chair and 'npc_citizen' or (job.test == 'goap' and 'npc_citizen' or 'npc_metropolice'))), 'current server body setting is respected')
		if job.test == 'goap' then
			local deadline = CurTime() + 30
			timer.Create('BGN_ScenicToolTest', 0.2, 0, function() Protect(function()
				assert(CurTime() < deadline and item.phase ~= 'timeout' and item.phase ~= 'model' and item.phase ~= 'ended', 'GOAP Tool test must finish: ' .. item.phase)
				if item.phase ~= 'done' then return end
				assert(actor:IsAlive() and actor:Health() == math.max(1, math.floor(actor:GetMaxHealth() * 0.25)), 'one test kick adds no damage')
				assert(not bgNPC.Util.IsDoorLocked(prop) and prop:GetInternalVariable('m_flSpeed') == 100, 'door settings are restored')
				assert(tool:Reload() and not actor:IsAlive(), 'R also removes actors after the door interaction ended')
				timer.Remove('BGN_ScenicToolTest')
				Passed(job)
			end) end)
			return
		end
		assert(actor:HasState('scenic_npc'), 'scene starts while the player watches')
		tool:RightClick({ Entity = npc })
		assert(tool.SelectedActor == actor, 'right-click selects the actual actor')
		if chair then
			assert(prop.occupied and npc:GetParent() == prop, 'chair finder positions the actor on the chair: occupied='
				.. tostring(prop.occupied) .. ', parent=' .. tostring(npc:GetParent()) .. ', chair=' .. tostring(prop)
				.. ', back=' .. tostring(actor:GetStateData().back and actor:GetStateData().back.chair))
			if job.test == 'chair_body_removed' then
				npc:Remove()
				timer.Simple(0.1, function() Protect(function()
					assert(not prop.occupied, 'external body removal releases the chair')
					assert(tool:Reload() and (prop.sitDelay or 0) <= CurTime(), 'removed-body test can be reset')
					Passed(job)
				end) end)
				return
			end
			assert(tool:Reload() and not prop.occupied and (prop.sitDelay or 0) <= CurTime(), 'R releases chair occupancy for immediate retesting')
			Passed(job)
		else
			prop:Fire('Open')
			timer.Simple(0.5, function() Protect(function()
				assert(actor:IsAlive() and not actor:HasState('scenic_npc'), 'opening the clicked door ends the scenic pose')
				assert(tool:Reload() and not actor:IsAlive(), 'R cleans up the released test actor')
				Passed(job)
			end) end)
		end
	end) end)
end

Protect(Next)
return { pending = true, report = 'bgn_scenic_tool_lab/tool.json' }
