snet.RegisterCallback('bgn_debug_send_actor_movement_path', function(ply, uid, path)
	local actor = bgNPC:GetActorByUid(uid)
	if not actor then return end
	actor.walkPath = path
end)

local clr_green = Color(72, 232, 9, 200)
local clr_line = Color(6, 72, 255)
local clr_line_to_npc = Color(255, 59, 59)
local color_white = Color(255, 255, 255)
local color_black = Color(0, 0, 0)
local vec_20 = Vector(0, 0, 20)

hook.Add('PostDrawOpaqueRenderables', 'BGN_Debug_MovementPathRender', function()
	if not GetConVar('bgn_debug'):GetBool() then return end

	render.SetColorMaterial()

	local actors = bgNPC:GetAll()
	
	for i = 1, #actors do
		local actor = actors[i]

		if actor and actor.walkPath and actor:IsAlive() then
			local count = #actor.walkPath

			if count ~= 0 then
				local pos = actor.walkPath[1]
				local ent = actor:GetNPC()
				local center_pos = LocalToWorld(ent:OBBCenter(), Angle(), ent:GetPos(), Angle())
				render.DrawLine(pos, center_pos, clr_line_to_npc)
			end

			for k = count, 1, -1 do
				local pos = actor.walkPath[k]

				if k ~= 1 then
					render.DrawLine(pos, actor.walkPath[k - 1], clr_line)
				end

				render.DrawSphere(pos, 10, 30, 30, clr_green)

				local cam_angle = LocalPlayer():EyeAngles()
				cam_angle:RotateAroundAxis(cam_angle:Forward(), 90)
				cam_angle:RotateAroundAxis(cam_angle:Right(), 90)

				cam.Start3D2D(pos + vec_20, cam_angle, 0.9)
					draw.SimpleTextOutlined(tostring(i), 
						"TargetID", 0, 0, color_white, 
						TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 0.5, color_black)
				cam.End3D2D()
			end
		end
	end
end)