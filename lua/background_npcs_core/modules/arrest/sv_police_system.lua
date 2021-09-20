-- Police System Integration
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2546066172

hook.Add('BGN_PlayerArrest', 'BGN_PoliceSystemIntegration_PlayerArrest', function(ply, actor)
	if not GetConVar('bgn_enable_police_system_support'):GetBool() then return end

	local police_system_hook = hook.Get('PlayerButtonDown', 'PoliceSysButton')
	if not police_system_hook then return end

	local fakePlayer = slib.Components.FakePlayer:Spawn('Police', ply:GetPos())
	fakePlayer:SetHealth(100)

	function fakePlayer:GetEyeTrace()
		return { Entity = ply }
	end

	fakePlayer:SetNWBool('PoliceOn', true)
	ply:SetNWBool('surrender', true)

	police_system_hook(ply, KEY_G)

	fakePlayer:slibCreateTimer('police_system_stage_2', 1.5, 1, function()
		for _, ent in ipairs(ents.FindByClass('arrested_entity')) do
			if ent.plyent == ply then
				function fakePlayer:GetEyeTrace()
					return { Entity = ent }
				end
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
end)