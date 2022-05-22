slib.Animator.RegisterAnimation('bgn_check_phone', 'models/animations/bgn/npc_phone.mdl', { 'idle' })

if CLIENT then
	local phone_model_path = Model('models/props_combine/combine_intmonitor001.mdl')
	local phone_models = {}

	hook.Add('Think', 'BGN_Animation_CheckPhone_SetupPosition', function()
		for i = #phone_models, 1, -1 do
			local value = phone_models[i]
			local anim_info = value.anim_info
			local animator = anim_info.animator
			if not IsValid(animator) then continue end

			local model = value.model
			local pos, ang = animator:GetBonePosition(anim_info.l_hand_bone_index)

			ang:RotateAroundAxis(ang:Up(), 280)
			ang:RotateAroundAxis(ang:Right(), -40)
			ang:RotateAroundAxis(ang:Forward(), 20)

			pos = pos - ang:Right() * 3
			pos = pos - ang:Up() * 4
			pos = pos - ang:Forward() * -2

			model:SetModelScale(.1)
			model:SetRenderAngles(ang)
			model:SetRenderOrigin(pos)
			model:SetupBones()
			model:SetNoDraw(false)
		end
	end)

	hook.Add('slib.AnimationPlaying', 'BGN_Animation_CheckPhone', function(anim_info)
		if anim_info.name ~= 'bgn_check_phone' then return end

		local animator = anim_info.animator
		timer.Simple(1.4, function()
			if not IsValid(animator) then return end
			local phone_moodel = ClientsideModel(phone_model_path, RENDERGROUP_OPAQUE)
			phone_moodel:SetOwner(animator)
			phone_moodel:SetParent(animator)
			phone_moodel:SetPos(animator:GetPos())
			phone_moodel:SetNoDraw(true)

			table.insert(phone_models, {
				model = phone_moodel,
				anim_info = anim_info
			})

			timer.Simple(5.5, function()
				if IsValid(phone_moodel) then
					for i = #phone_models, 1, -1 do
						local value = phone_models[i]
						if IsValid(value.model) and value.model == phone_moodel then
							table.remove(phone_models, i)
						end
					end
					phone_moodel:Remove()
				end
			end)
		end)
	end)
end