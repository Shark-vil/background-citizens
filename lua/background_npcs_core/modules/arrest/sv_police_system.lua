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

	local police_system_hook = slib.Component('Hook', 'Get', 'PlayerButtonDown', 'PoliceSysButton')
	if not police_system_hook then return end

	local target_pos = target:GetPos()
	actor:GetStateData().ps_arrest_target_pos = target_pos

	local fakePlayer = MakeFakePlayer(target_pos, target)
	local arrestEntity = HPZ_PoliceSystem:CreateArrestEntity(target)
	function fakePlayer:GetEyeTrace() return { Entity = arrestEntity } end
	function fakePlayer:GetActiveWeapon()
		local Weapon = {}
		function Weapon:GetClass() end
		return Weapon
	end

	if target:IsPlayer() then target:KillSilent() end

	timer.Create('police_system_stage_2_' .. slib.UUID(), 1.5, 1, function()
		if not actor or not actor:IsAlive() or not IsValid(fakePlayer) or not IsValid(arrestEntity) then
			return
		end

		HPZ_PoliceSystem:DownArrestEntity(arrestEntity)

		fakePlayer:slibCreateTimer('police_system_stage_3', 2, 1, function()
			arrestEntity:Use(fakePlayer)
		end)
	end)

	fakePlayer:slibAutoDestroy(5)

	return true
end)