local IsValid = IsValid
local ClientsideModel = ClientsideModel
--

snet.RegisterCallback('slib_animator_destroyed', function(_, ent)
	slib.Animator.ClearInactive(ent)
end).Validator(SNET_ENTITY_VALIDATOR)

snet.Callback('slib_animator_create_clientside_model', function(ply, anim)
	local entity = anim.entity
	local animator = anim.animator

	if not IsValid(entity) or not IsValid(animator) then return end

	local position = animator:GetPos()
	local rotation = animator:GetAngles()
	local animation_model = ClientsideModel(entity:GetModel(), RENDERGROUP_OPAQUE)
	animation_model:SetPos(position)
	animation_model:SetAngles(rotation)
	animation_model:SetOwner(animator)
	animation_model:SetParent(animator)
	animation_model:AddEffects(EF_BONEMERGE + EF_BONEMERGE_FASTCULL)
	animation_model:SetNoDraw(true)
	animation_model:DrawShadow(true)

	for _, bodygroup in ipairs(entity:GetBodyGroups()) do
		local id = bodygroup.id
		animation_model:SetBodygroup(id, entity:GetBodygroup(id))
	end

	animation_model:SetSkin(entity:GetSkin())

	local weapon
	local weapon_model
	local r_hand = animator:LookupBone('ValveBiped.Bip01_R_Hand')
	local l_hand = animator:LookupBone('ValveBiped.Bip01_L_Hand')

	if entity:IsNPC() or entity:IsPlayer() then
		weapon = entity:GetActiveWeapon()

		if IsValid(weapon) and r_hand then
			local b_pos, b_ang = animator:GetBonePosition(r_hand)
			local world_weapon_model = weapon:GetWeaponWorldModel()
			if b_pos and b_ang and world_weapon_model then
				weapon_model = ClientsideModel(world_weapon_model, RENDERGROUP_OPAQUE)
				if IsValid(weapon_model) then
					weapon_model:SetPos(b_pos)
					weapon_model:SetAngles(b_ang)
					weapon_model:SetOwner(animator)
					weapon_model:SetParent(animator)
					weapon_model:AddEffects(EF_BONEMERGE + EF_BONEMERGE_FASTCULL)
					weapon_model:SetNoDraw(true)
					weapon_model:DrawShadow(true)

					for _, bodygroup in ipairs(weapon:GetBodyGroups()) do
						local id = bodygroup.id
						weapon_model:SetBodygroup(id, weapon:GetBodygroup(id))
					end

					weapon_model:SetSkin(weapon:GetSkin())
				end
			end
		end
	end

	anim.model = animation_model
	anim.weapon_model = weapon_model
	anim.r_hand_bone_index = r_hand
	anim.l_hand_bone_index = l_hand
	anim.weapon = weapon
	anim.material = entity:GetMaterial()

	table.insert(slib.Storage.ActiveAnimations, anim)
	hook.Run('slib.PreAnimationPlay', anim)
end).Validator(SNET_DEEP_ENTITY_VALIDATOR)

snet.Callback('slib_animator_play', function(ply, _animator)
	if not IsValid(_animator) then return end

	for i = 1, #slib.Storage.ActiveAnimations do
		local value = slib.Storage.ActiveAnimations[i]
		if value.animator == _animator then
			local entity = value.entity
			local model = value.model
			local weapon_model = value.weapon_model
			local animator = value.animator
			local material = value.material
			local weapon = value.weapon

			if not IsValid(model) then continue end

			if not entity:IsPlayer() then
				model:SetNoDraw(false)
				if IsValid(weapon_model) then
					weapon_model:SetNoDraw(false)
				end
			end

			entity:SetMaterial('invisible')
			animator:ResetSequence(value.sequence_id)
			animator:SetNoDraw(true)
			animator:DrawShadow(false)

			if IsValid(weapon) then
				weapon:SetNoDraw(true)
			end

			value.is_played = true
			hook.Run('slib.AnimationPlaying', value)

			local timer_name = 'animator_' .. slib.UUID()

			timer.Create(timer_name, value.time, 0, function()
				if value.settings.loop and IsValid(entity) and IsValid(animator) then
					value.stop_time = CurTime() + value.time
					animator:ResetSequence(value.sequence_id)
					return
				else
					timer.Remove(timer_name)
				end

				if slib.Storage.ActiveAnimations[i] then
					value = slib.Storage.ActiveAnimations[i]
					value.is_played = false
					entity = value.entity
					model = value.model
					weapon_model = value.weapon_model
					material = value.material
					weapon = value.weapon
				end

				if IsValid(weapon_model) then weapon_model:Remove() end
				if IsValid(model) then model:Remove() end
				if IsValid(entity) then entity:SetMaterial(material) end
				if IsValid(weapon) then weapon:SetNoDraw(false) end
			end)

			break
		end
	end
end).Validator(SNET_ENTITY_VALIDATOR)