local default_color_target = Color(255, 0, 0)
local police_color_target = Color(0, 0, 255)
local residents_color_target = Color(0, 255, 0)
local state_text_color = Color(255, 255, 255)
local text_border_color = Color(0, 0, 0)
local target_color = Color(100, 255, 255)

surface.CreateFont("BGN_Debug_UpperStateText", {
	font = "Arial",
	extended = false,
	size = 24,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
})

local function GetCenterEntityPos(ent)
   return LocalToWorld(ent:OBBCenter(), Angle(), ent:GetPos(), Angle())
end

local function GetColorByTeam(actor)
   if actor:HasTeam('police') then
      return police_color_target
   elseif actor:HasTeam('residents') then
      return residents_color_target
   end
   return default_color_target
end

hook.Add('PostDrawOpaqueRenderables', 'BGN_Debug_RenderTargetsPath', function()
   if not GetConVar('bgn_debug'):GetBool() then return end

   local ply = LocalPlayer()
   if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

   local upper_text_angle = ply:EyeAngles()
   upper_text_angle:RotateAroundAxis(upper_text_angle:Forward(), 90)
   upper_text_angle:RotateAroundAxis(upper_text_angle:Right(), 90)
   
   render.SetColorMaterial()

   for _, actor in ipairs(bgNPC:GetAll()) do
      if actor:IsAlive() then
         local npc = actor:GetNPC()
         local npc_pos = npc:GetPos()

         if npc_pos:DistToSqr(ply:GetPos()) < 640000 then         
            cam.Start3D2D(npc_pos + npc:GetForward() + npc:GetUp() * 78, upper_text_angle, 0.25)
               draw.SimpleTextOutlined('State - ' .. actor:GetState(), "BGN_Debug_UpperStateText", 0, -15, state_text_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, text_border_color)
            cam.End3D2D()
         end

         for _, enemy in ipairs(actor.enemies) do
            if IsValid(enemy) then
               local color = GetColorByTeam(actor)
               render.DrawLine(npc:EyePos(), GetCenterEntityPos(enemy), color)
            end
         end

         for _, target in ipairs(actor.targets) do
            if IsValid(target) then
               render.DrawLine(GetCenterEntityPos(npc), GetCenterEntityPos(target), target_color)
            end
         end
      end
   end
end)