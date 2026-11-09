local debug_cvar = GetConVar('bgn_debug')
local rows, summary, received_at = {}, nil, 0
local normal = Color(100, 200, 255)
local spawned = Color(80, 255, 100)
local teleported = Color(255, 190, 50)
local outline = Color(0, 0, 0, 230)
local lod_names = { 'near', 'far', 'dormant' }

local function Allowed()
	local ply = LocalPlayer()
	return debug_cvar:GetBool() and IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin())
end

bgNPC.Net.Receive('bgn.debug_actors', function(_, actors, info)
	if not Allowed() then rows, summary = {}, nil return end
	rows, summary, received_at = actors, info, RealTime()
end)

cvars.AddChangeCallback('bgn_debug', function()
	rows, summary = {}, nil
end, 'BGN_Debug_ActorOverlay')

local function Age(value)
	return value and value + RealTime() - received_at
end

local function ColorFor(row)
	if row.teleport_age and Age(row.teleport_age) < 5 then return teleported end
	if row.spawn_age and Age(row.spawn_age) < 5 then return spawned end
	return normal
end

-- Remove the old passes when scripts are reloaded in an existing session.
hook.Remove('PostDrawTranslucentRenderables', 'BGN_Debug_ActorOverlay')
hook.Remove('HUDPaint', 'BGN_Debug_ActorOverlay')

local function DrawBounds()
	cam.Start3D()
	cam.IgnoreZ(true)
	render.SetColorMaterial()
	for _, row in ipairs(rows) do
		if not row.in_vehicle then render.DrawWireframeBox(row.pos, row.ang, row.mins, row.maxs, ColorFor(row), true) end
		if row.spawn_pos and Age(row.spawn_age) < 5 then
			render.DrawWireframeSphere(row.spawn_pos, 25, 8, 4, spawned, true)
		end
		if row.teleport_pos and Age(row.teleport_age) < 5 then
			render.DrawWireframeSphere(row.teleport_pos, 35, 8, 4, teleported, true)
		end
	end
	cam.IgnoreZ(false)
	cam.End3D()
end

local function Text(text, x, y, color, align)
	draw.SimpleTextOutlined(text, 'DermaDefault', x, y, color or normal, align or TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP, 1, outline)
end

hook.Add('PostDrawHUD', 'BGN_Debug_ActorOverlay', function()
	if not Allowed() or not summary or RealTime() - received_at >= 2 then return end
	DrawBounds()
	local eye = EyePos()
	for _, row in ipairs(rows) do
		local screen = (row.pos + Vector(0, 0, row.maxs.z + 15)):ToScreen()
		if screen.visible then
			local color = ColorFor(row)
			local age = row.spawn_age and string.format(' | age %.1fs', Age(row.spawn_age)) or ''
			local event = row.teleport_age and Age(row.teleport_age) < 5 and ' TELEPORT'
				or (row.spawn_age and Age(row.spawn_age) < 5 and ' SPAWN' or '')
			Text(string.format('%s #%s%s', row.type, tostring(row.uid), event), screen.x, screen.y, color, TEXT_ALIGN_CENTER)
			Text(string.format('%s | HP %d | %.0fu%s', row.state, row.hp, row.pos:Distance(eye), age),
				screen.x, screen.y + 13, color, TEXT_ALIGN_CENTER)
			Text(string.format('%s/%s | %s | enemies %d / targets %d', row.body, row.brain,
				lod_names[row.lod] or '?', row.enemies or 0, row.targets or 0), screen.x, screen.y + 26, color, TEXT_ALIGN_CENTER)
		end
	end
	Text(string.format('BGN DEBUG | server actors %d | FPS %.0f', #rows, 1 / math.max(RealFrameTime(), 0.001)), 20, 180)
	Text(string.format('nav %s (%d points) | tasks %.2f ms | lag %s', summary.nav, summary.points,
		summary.tasks_ms, summary.lagging and 'YES' or 'no'), 20, 195)
	Text('Green: spawn <5s | Yellow: teleport <5s | Blue: existing | snapshots: 0.5s', 20, 210)
	for i, item in ipairs(summary.types) do
		Text(string.format('%s: %d / %d', item.name, item.count, item.limit), 20, 225 + (i - 1) * 14)
	end
end)
