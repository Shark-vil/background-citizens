local bgNPC = bgNPC
local hook = hook
local render = render
local TEXT_ALIGN_CENTER = TEXT_ALIGN_CENTER
local GetConVar = GetConVar
local LocalPlayer = LocalPlayer
local LocalToWorld = LocalToWorld
local render_SetColorMaterial = render.SetColorMaterial
local render_DrawLine = render.DrawLine
local render_DrawSphere = render.DrawSphere
local cam_Start3D2D = cam.Start3D2D
local cam_End3D2D = cam.End3D2D
local draw_SimpleTextOutlined = draw.SimpleTextOutlined
--

local function DebugIsEnabled()
	if not GetConVar('bgn_debug'):GetBool() then return false end
	if not GetConVar('bgn_cl_draw_npc_path'):GetBool() then return false end
	return true
end

snet.RegisterCallback('bgn_debug_send_actor_movement_path', function(ply, uid, path)
	if not DebugIsEnabled() then return end

	local actor = bgNPC:GetActorByUid(uid)
	if not actor then return end
	actor.walkPath = path
end)

local text_font_name = 'TargetID'
local clr_green = Color(72, 232, 9, 200)
local clr_line = Color(6, 72, 255)
local clr_line_to_npc = Color(255, 59, 59)
local color_white = Color(255, 255, 255)
local color_black = Color(0, 0, 0)
local vec_20 = Vector(0, 0, 20)

hook.Add('PostDrawOpaqueRenderables', 'BGN_Debug_MovementPathRender', function()
	if not DebugIsEnabled() then return end

	render_SetColorMaterial()

	local actors = bgNPC:GetAll()
	local ply = LocalPlayer()
	local plyPosition = ply:GetPos()
	local cam_angle = ply:EyeAngles()
	cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
	cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor.walkPath and actor:IsAlive() then
			local count = #actor.walkPath
			local npc = actor:GetNPC()
			local npcPosition = npc:GetPos()

			if npcPosition:DistToSqr(plyPosition) > 250000 then continue end

			if count ~= 0 then
				local pos = actor.walkPath[1]
				local center_pos = LocalToWorld(npc:OBBCenter(), Angle(), npc:GetPos(), Angle())
				render_DrawLine(pos, center_pos, clr_line_to_npc)
			end

			for k = count, 1, -1 do
				local pos = actor.walkPath[k]

				if k ~= 1 then
					render_DrawLine(pos, actor.walkPath[k - 1], clr_line)
				end

				render_DrawSphere(pos, 10, 5, 5, clr_green)

				cam_Start3D2D(pos + vec_20, cam_angle, 0.9)
					draw_SimpleTextOutlined(tostring(count - k + 1),
						text_font_name, 0, 0, color_white,
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				cam_End3D2D()
			end
		end
	end
end)