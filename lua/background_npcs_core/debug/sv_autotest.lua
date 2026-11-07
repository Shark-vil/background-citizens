--[[
	In-game smoke test, used by the development harness.
	Does nothing unless "data/bgn_autotest/run.txt" exists
	(JSON: { "duration": 60, "commands": ["bgn_max_npc 30"], "fight": 10 }).
	"fight": seconds after start when a gangster hits the nearest citizen (exercises reactions and GOAP).
	The trigger file is deleted on start. The report is written to "data/bgn_autotest/report.json".
	Manual run: "bgn_autotest [seconds]".
--]]

local TRIGGER = 'bgn_autotest/run.txt'
local REPORT = 'bgn_autotest/report.json'

-- GOAP observations over the run: "set/goal/action" -> samples seen
local goap_seen, goap_examples = {}, {}

local function SampleGOAP()
	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local brain = actor.brain
		if brain and brain.plan and brain.goal then
			local action = brain.plan[brain.step]
			local key = brain.set_name .. '/' .. brain.goal.name .. '/' .. (action and action.name or '-')
			goap_seen[key] = (goap_seen[key] or 0) + 1
			if not goap_examples[key] then goap_examples[key] = actor:GetType() .. ': ' .. brain:Describe() end
		end
	end
end

-- A gangster hits the nearest citizen, through the normal damage path.
local function Provoke()
	local gangster = bgNPC.Actors.GetByType('gangster')[1]
	if not gangster then MsgN('[BGN AUTOTEST] fight: no gangster') return end
	local attacker = gangster:GetNPC()
	local victim, best
	for _, actor in ipairs(bgNPC.Actors.GetByType('citizen')) do
		local dist = actor:GetNPC():GetPos():DistToSqr(attacker:GetPos())
		if not best or dist < best then victim, best = actor:GetNPC(), dist end
	end
	if not IsValid(victim) then MsgN('[BGN AUTOTEST] fight: no citizen') return end

	local dmg = DamageInfo()
	dmg:SetDamage(5)
	dmg:SetAttacker(attacker)
	dmg:SetInflictor(attacker)
	dmg:SetDamageType(DMG_CLUB)
	victim:TakeDamageInfo(dmg)
	MsgN('[BGN AUTOTEST] fight: gangster hit a citizen at ' .. math.floor(math.sqrt(best)) .. ' units')
end

local function CollectReport(samples, started_at)
	local by_type, by_state, by_brain, by_body, by_lod = {}, {}, {}, {}, {}

	for _, actor in ipairs(bgNPC.Actors.GetAll()) do
		local actor_type = actor:GetType()
		by_type[actor_type] = (by_type[actor_type] or 0) + 1
		local state = actor:GetState()
		by_state[state] = (by_state[state] or 0) + 1
		local brain = actor.brain and actor.brain.ClassName or 'none'
		by_brain[brain] = (by_brain[brain] or 0) + 1
		local body = actor.body and actor.body.ClassName or 'none'
		by_body[body] = (by_body[body] or 0) + 1
		local lod = tostring(actor.lod)
		by_lod[lod] = (by_lod[lod] or 0) + 1
	end

	local task_ms_sum, task_ms_max, frame_sum = 0, 0, 0
	for _, s in ipairs(samples) do
		task_ms_sum = task_ms_sum + s.task_ms
		task_ms_max = math.max(task_ms_max, s.task_ms)
		frame_sum = frame_sum + s.frame
	end
	local n = math.max(1, #samples)

	local nav = bgNPC.Nav and bgNPC.Nav.GetInfo and bgNPC.Nav.GetInfo() or {}

	return {
		map = game.GetMap(),
		duration = CurTime() - started_at,
		actors = #bgNPC.Actors.GetAll(),
		by_type = by_type,
		by_state = by_state,
		by_brain = by_brain,
		by_body = by_body,
		by_lod = by_lod,
		tasks_ms_avg = task_ms_sum / n,
		tasks_ms_max = task_ms_max,
		frame_ms_avg = frame_sum / n * 1000,
		selftest_ok = bgNPC.Test.last_ok,
		nav = nav,
		goap_seen = goap_seen,
		goap_examples = goap_examples,
		extra = bgNPC.AutoTestExtra and bgNPC.AutoTestExtra() or nil,
	}
end

local function Run(duration, commands, fight)
	goap_seen, goap_examples = {}, {}
	MsgN('[BGN AUTOTEST] start, ' .. duration .. 's')

	for _, command in ipairs(commands or {}) do
		local args = string.Explode(' ', command)
		RunConsoleCommand(unpack(args))
	end

	bgNPC.Test.last_ok = bgNPC.Test.Run()
	for _, ply in ipairs(player.GetHumans()) do ply:ConCommand('bgn_selftest_cl') end

	local started_at = CurTime()
	local samples = {}

	timer.Create('BGN_AutoTest_Sample', 0.5, 0, function()
		samples[#samples + 1] = { task_ms = bgNPC.Tasks.last_tick_ms, frame = FrameTime() }
		SampleGOAP()
	end)

	if fight then timer.Simple(fight, Provoke) end

	timer.Simple(duration, function()
		timer.Remove('BGN_AutoTest_Sample')
		local report = CollectReport(samples, started_at)
		file.CreateDir('bgn_autotest')
		file.Write(REPORT, util.TableToJSON(report, true))
		MsgN('[BGN AUTOTEST] done: ' .. util.TableToJSON(report))
	end)
end

hook.Add('BGN_PlayerReady', 'BGN_AutoTest', function()
	if not file.Exists(TRIGGER, 'DATA') then return end

	local config = util.JSONToTable(file.Read(TRIGGER, 'DATA') or '') or {}
	file.Delete(TRIGGER)

	timer.Simple(config.delay or 5, function()
		Run(config.duration or 60, config.commands, config.fight)
	end)
end)

concommand.Add('bgn_autotest', function(ply, _, args)
	if IsValid(ply) and not ply:IsSuperAdmin() then return end
	Run(tonumber(args[1]) or 30)
end)
