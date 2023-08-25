local bgNPC = bgNPC
local timer = timer
local hook = hook
local player = player
local table = table
local IsValid = IsValid
local ipairs = ipairs
local GetConVar = GetConVar
--

hook.Add('PostCleanupMap', 'BGN_CleanDvCarsCache', function()
	bgNPC.DVCars = {}
end)

hook.Add('BGN_DvCarRemoved', 'BGN_DVCars_OnRemoved', function(vehicle_provider)
	for _, actor in ipairs(vehicle_provider:GetPassengers()) do
		local npc = actor:GetNPC()
		if IsValid(npc) then npc:Remove() end
	end
end)

timer.Create('BGN_Timer_DVCars_Remover', 1, 0, function()
	local count = #bgNPC.DVCars
	if count == 0 then return end
	local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	local bgn_enable = GetConVar('bgn_enable'):GetBool()
	local dv_support_enable = GetConVar('bgn_enable_dv_support'):GetBool()

	for i = count, 1, -1 do
		local vehicle_provider = bgNPC.DVCars[i]
		local vehicle = vehicle_provider:GetVehicle()

		if not IsValid(vehicle) or not bgn_enable or not dv_support_enable or player.GetCount() == 0 then
			hook.Run('BGN_DvCarRemoved', vehicle_provider)
			vehicle_provider:Remove()
			table.remove(bgNPC.DVCars, i)
		else
			local driver = vehicle_provider:GetDriver()

			if not driver and vehicle_provider:IsValidAI() then
				vehicle_provider:GetVehicleAI():Remove()
			end

			local isRemove = true
			local vehicle_position = vehicle:GetPos()

			for _, ply in ipairs(player.GetAll()) do
				if IsValid(ply) then
					local player_position = ply:GetPos()
					local dist = vehicle_position:DistToSqr(player_position)

					if dist < bgn_spawn_radius or bgNPC:PlayerIsViewVector(ply, vehicle_position) then
						isRemove = false
						break
					end
				end
			end

			if isRemove then
				hook.Run('BGN_DvCarRemoved', vehicle_provider)
				vehicle_provider:Remove()
				table.remove(bgNPC.DVCars, i)
			end
		end
	end
end)