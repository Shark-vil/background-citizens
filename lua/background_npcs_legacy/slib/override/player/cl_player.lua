--
local meta = FindMetaTable('Player')
local infelicity_calcview = 0
local is_another_camera = false
local LocalPlayer = LocalPlayer

snet.RegisterCallback('slib_player_notify', function(ply, text, message_type, length, sound_path)
	ply:slibNotify(text, message_type, length, sound_path)
end)

hook.Add('slib.FirstPlayerSpawn', 'SlibInitializeGlobalClientLanguage', function(ply)
	if ply ~= LocalPlayer() then return end
	snet.InvokeServer('slib_player_set_language', GetConVar('cl_language'):GetString())
	cvars.AddChangeCallback('cl_language', function(_, _, new_language)
		snet.InvokeServer('slib_player_set_language', tostring(new_language))
	end)
end)

hook.Add('PreDrawOpaqueRenderables', 'SlibCheckPPlayerCameraPosition', function()
	local ply = LocalPlayer()
	if GetViewEntity() ~= ply then
		is_another_camera = true
	else
		local player_eye_pos = ply:EyePos()
		local global_eye_pos = EyePos()
		if player_eye_pos:DistToSqr(global_eye_pos) <= 50 then
			if infelicity_calcview ~= 0 then
				infelicity_calcview = 0
			end
		else
			if infelicity_calcview + 1 <= 5 then
				infelicity_calcview = infelicity_calcview + 1
			end
		end
		is_another_camera = infelicity_calcview == 5
	end
end)


function meta:slibHasUseAnotherCamera()
	return is_another_camera
end