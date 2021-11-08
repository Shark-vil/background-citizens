-- Police System Integration
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2546066172

local function MakeFakePlayer(position)
	local fakePlayer = slib.Components.FakePlayer:Spawn('Police', position)
	fakePlayer:SetHealth(100)
	fakePlayer:SetNWBool('PoliceOn', true)
	return fakePlayer
end

hook.Add('BGN_PlayerArrestStop', 'BGN_PoliceSystemIntegration_Animation', function(actor, state, data)
	if not GetConVar('bgn_enable_police_system_support'):GetBool() then return end

	local target_pos = actor:GetStateData().ps_arrest_target_pos
	if target_pos then
		local npc = actor:GetNPC()
		local npc_angle = npc:GetAngles()
		local npc_new_angle = (target_pos - npc:GetPos()):Angle()
		npc:SetAngles(Angle(npc_angle.x, npc_new_angle.y, npc_angle.z))
	end

	actor:PlayStaticSequence('Shoot_To_Crouchpistol', false, nil, function()
		actor:PlayStaticSequence('Crouch_Idle_Pistol', true, 3, function()
			actor:PlayStaticSequence('Crouch_To_Shootpistol')
		end)
	end)
end)

hook.Add('BGN_PlayerArrest', 'BGN_PoliceSystemIntegration_PlayerArrest', function(target, actor)
	if not GetConVar('bgn_enable_police_system_support'):GetBool() then return end

	local police_system_hook = hook.Get('PlayerButtonDown', 'PoliceSysButton')
	if not police_system_hook then return end

	local target_is_player = target:IsPlayer()
	local target_pos = target:GetPos()
	actor:GetStateData().ps_arrest_target_pos = target_pos

	local fakePlayer = MakeFakePlayer(target_pos, target)

	function fakePlayer:GetEyeTrace() return { Entity = target } end

	target:SetNWBool('surrender', true)

	if target_is_player then
		police_system_hook(target, KEY_G)
	else
		police_system_hook(fakePlayer, KEY_G)
	end

	timer.Create('police_system_stage_2_' .. slib.GetUid(), 1.5, 1, function()
		if not actor or not actor:IsAlive() then return end
		if not fakePlayer or not IsValid(fakePlayer) then
			fakePlayer = MakeFakePlayer(target_pos)
		end

		for _, ent in ipairs(ents.FindByClass('arrested_entity')) do
			if (target_is_player and ent.plyent == target) or target_pos:DistToSqr(ent:GetPos()) <= 250000 then
				function fakePlayer:GetEyeTrace() return { Entity = ent } end
				police_system_hook(fakePlayer, KEY_G)

				fakePlayer:slibCreateTimer('police_system_stage_3', 2, 1, function()
					function fakePlayer:GetActiveWeapon()
						local Weapon = {}
						function Weapon:GetClass() end
						return Weapon
					end

					ent:Use(fakePlayer)
				end)

				break
			end
		end
	end)

	fakePlayer:slibAutoDestroy(5)

	return true
end)