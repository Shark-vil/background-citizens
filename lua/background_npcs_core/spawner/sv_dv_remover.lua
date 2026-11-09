--

local function PlayerCanSeeVehicle(ply, vehicle, points)
	local seat = ply:GetVehicle()
	while IsValid(seat) do
		if seat == vehicle then return true end
		seat = seat:GetParent()
	end
	local viewer = ply:GetViewEntity()
	if not IsValid(viewer) then viewer = ply end
	local eye = viewer:EyePos()
	points[#points] = vehicle:NearestPoint(eye)
	for _, point in ipairs(points) do
		if bgNPC.Vision.PlayerCanSeePos(ply, point) then return true end
		local tr = util.TraceLine({ start = eye, endpos = point, filter = { ply, viewer }, mask = MASK_VISIBLE })
		if not tr.Hit then return true end
		local hit = tr.Entity
		while IsValid(hit) do
			if hit == vehicle then return true end
			hit = hit:GetParent()
		end
	end
	return false
end

local function CanCleanAbandonedVehicle(provider, vehicle, now, timeout)
	if not vehicle.isBgnVehicle or timeout <= 0 then return false end
	local pos = vehicle:GetPos()
	-- Compare with a fixed anchor, not the previous tick: rocking back and forth is not progress.
	if not provider.cleanupAnchor or provider.cleanupAnchor:DistToSqr(pos) > 128 ^ 2 then
		provider.cleanupAnchor, provider.cleanupMovedAt = pos, now
	end
	if provider:GetDriver() then
		provider.cleanupEmptySince = nil
	elseif not provider.cleanupEmptySince then
		provider.cleanupEmptySince = now
	end
	if now - provider.cleanupMovedAt < timeout
		and (not provider.cleanupEmptySince or now - provider.cleanupEmptySince < timeout) then return false end
	return true
end

local function VehicleIsHidden(vehicle, players)
	local mins, maxs = vehicle:OBBMins(), vehicle:OBBMaxs()
	local center = vehicle:OBBCenter()
	local points = { vehicle:LocalToWorld(center) }
	-- Corners and face centers protect partly exposed cars; a hull sweep can miss these behind cover.
	-- shortcut: samples can miss tiny gaps between points; add samples if a map needs finer visibility checks.
	for _, x in ipairs({ mins.x, maxs.x }) do
		for _, y in ipairs({ mins.y, maxs.y }) do
			for _, z in ipairs({ mins.z, maxs.z }) do
				points[#points + 1] = vehicle:LocalToWorld(Vector(x, y, z))
			end
		end
	end
	for _, bound in ipairs({ mins, maxs }) do
		points[#points + 1] = vehicle:LocalToWorld(Vector(bound.x, center.y, center.z))
		points[#points + 1] = vehicle:LocalToWorld(Vector(center.x, bound.y, center.z))
		points[#points + 1] = vehicle:LocalToWorld(Vector(center.x, center.y, bound.z))
	end
	points[#points + 1] = points[1] -- replaced with the closest surface point for each player
	for _, ply in ipairs(players) do
		if IsValid(ply) and PlayerCanSeeVehicle(ply, vehicle, points) then return false end
	end
	return true
end

hook.Add('PostCleanupMap', 'BGN_CleanDvCarsCache', function()
	bgNPC.DVCars = {}
end)

hook.Add('BGN_DvCarRemoved', 'BGN_DVCars_OnRemoved', function(vehicle_provider)
	vehicle_provider:RemoveActors()
end)

timer.Create('BGN_Timer_DVCars_Remover', 1, 0, function()
	local count = #bgNPC.DVCars
	if count == 0 then return end
	local bgn_spawn_radius = GetConVar('bgn_spawn_radius'):GetFloat() ^ 2
	local bgn_enable = GetConVar('bgn_enable'):GetBool()
	local dv_support_enable = GetConVar('bgn_enable_dv_support'):GetBool()
	local cleanup_time = GetConVar('bgn_vehicle_cleanup_time'):GetFloat()
	local players, now = player.GetAll(), CurTime()

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

			local abandoned = CanCleanAbandonedVehicle(vehicle_provider, vehicle, now, cleanup_time)
			for _, ply in ipairs(players) do
				if IsValid(ply) then
					local player_position = ply:GetPos()
					local dist = vehicle_position:DistToSqr(player_position)

					if dist < bgn_spawn_radius or bgNPC.Vision.PlayerCanSeePos(ply, vehicle_position) then
						isRemove = false
						break
					end
				end
			end

			if (isRemove or abandoned) and VehicleIsHidden(vehicle, players) then
				hook.Run('BGN_DvCarRemoved', vehicle_provider)
				vehicle_provider:Remove()
				table.remove(bgNPC.DVCars, i)
			end
		end
	end
end)
