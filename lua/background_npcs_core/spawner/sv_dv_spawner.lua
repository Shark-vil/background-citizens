--

local simfphys_forward = {}

local function AlignSimfphysSpawn(vehicle, class, desired)
	vehicle.bgnHeadingPending = true
	local attempts = 0
	bgNPC.Util.EntityTimer(vehicle, 'bgn_spawn_heading', .05, 40, function(car)
		attempts = attempts + 1
		local forward = car.VehicleData and car.VehicleData.LocalAngForward
		if not forward then
			if attempts == 40 then
				bgNPC.Util.Log('Vehicle heading did not initialize: ' .. class, 'SpawnVehicle')
				car:Remove()
			end
			return
		end
		simfphys_forward[class] = forward.y
		local correction = math.AngleDifference(desired.y, car:LocalToWorldAngles(forward).y)
		if math.abs(correction) > .5 then
			local pivot, rotation = car:GetPos(), Angle(0, correction, 0)
			local objects = {}
			-- Rotate the constrained assembly from a snapshot, not just the chassis with its wheels left behind.
			for ent in pairs(constraint.GetAllConstrainedEntities(car)) do
				if IsValid(ent) then
					for i = 0, ent:GetPhysicsObjectCount() - 1 do
						local phys = ent:GetPhysicsObjectNum(i)
						if IsValid(phys) then objects[#objects + 1] = { phys, phys:GetPos(), phys:GetAngles(), phys:GetVelocity() } end
					end
				end
			end
			car:SetAngles(car:GetAngles() + rotation)
			for _, object in ipairs(objects) do
				local phys, pos, ang, vel = unpack(object)
				pos = pos - pivot; pos:Rotate(rotation)
				ang:RotateAroundAxis(vector_up, correction); vel:Rotate(rotation)
				phys:SetPos(pivot + pos); phys:SetAngles(ang); phys:SetVelocity(vel); phys:Wake()
			end
		end
		car.bgnHeadingPending = nil
		bgNPC.Util.RemoveEntityTimer(car, 'bgn_spawn_heading')
	end)
end

local function GetNearPoints(center, radius)
	radius = radius ^ 2
	local dvd = DecentVehicleDestination
	local points = {}

	for i = 1, #dvd.Waypoints do
		local point = dvd.Waypoints[i]

		if point and point.Target:DistToSqr(center) <= radius then
			table.insert(points, point)
		end
	end

	return points
end

-- Where the player will be in a moment: a car that spawns on the road ahead lands on the hood.
local function PlayerAheadPoints(ply)
	local car = ply:GetVehicle()
	if IsValid(car) and IsValid(car:GetParent()) then car = car:GetParent() end
	local shift = (IsValid(car) and car or ply):GetVelocity() * 1.5
	if shift:LengthSqr() > 1500 ^ 2 then shift = shift:GetNormalized() * 1500 end
	local pos = ply:GetPos()
	return pos + shift * .5, pos + shift
end

-- A car is bigger than a spawn point: a hidden centre can still show a fender around a corner.
-- shortcut: a fixed 260x260 grid covers any heading and most cars; thin gaps between samples are not checked.
local HULL_OFFSETS = {}
for _, x in ipairs({ -130, 0, 130 }) do
	for _, y in ipairs({ -130, 0, 130 }) do
		for _, z in ipairs({ 10, 100 }) do HULL_OFFSETS[#HULL_OFFSETS + 1] = Vector(x, y, z) end
	end
end

-- @return boolean true when no part of a car standing at `base` can be seen by the player
local function HullHiddenFrom(ply, base)
	local eye, car = ply:EyePos(), ply:GetVehicle()
	local filter = { ply, car, IsValid(car) and car:GetParent() or nil }
	for _, offset in ipairs(HULL_OFFSETS) do
		local point = base + offset
		if bgNPC.Util.IsInView(ply, point) then
			local tr = util.TraceLine({ start = eye, endpos = point, mask = MASK_VISIBLE, filter = filter })
			if not tr.Hit or tr.HitPos:DistToSqr(point) < 64 then return false end
		end
	end
	return true
end

local function FindSpawnLocation(center, radius)
	local spawn_radius = radius or GetConVar('bgn_spawn_radius'):GetFloat()
	local points = GetNearPoints(center, spawn_radius)
	if #points == 0 then return nil end

	points = bgNPC.Table.Shuffle(points)
	local dvd = DecentVehicleDestination
	local block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2
	local visibility_radius = GetConVar('bgn_vehicle_spawn_visibility_radius'):GetFloat() ^ 2
	local all_players = player.GetAll()
	local spawn_position = nil
	local spawn_angle = nil

	for i = 1, #points do
			local point = points[i]
			spawn_position = point.Target

			for k = 1, #all_players do
				local ply = all_players[k]
				local vehicle = ply:GetVehicle()
				local distance = spawn_position:DistToSqr(ply:GetPos())

				local mid, ahead = PlayerAheadPoints(ply)
				if distance <= block_radius or spawn_position:DistToSqr(mid) <= block_radius
					or spawn_position:DistToSqr(ahead) <= block_radius then
					goto skip
				end

				if bgNPC.Util.IsInView(ply, spawn_position) then
					-- close to the player the whole car must be behind cover, not just its centre
					if distance <= visibility_radius then
						if not HullHiddenFrom(ply, spawn_position + Vector(0, 30, 0)) then goto skip end
					else
						local tr = util.TraceLine({
							start = ply:EyePos(),
							endpos = spawn_position,
							filter = function(ent)
								if IsValid(ent) and ent ~= ply then
									if IsValid(vehicle) then
										if ent ~= vehicle and ent ~= vehicle:GetParent() then
											return false
										end
									else
										return true
									end
								end
							end
						})

						if not tr.Hit then
							goto skip
						elseif tr.Entity:GetClass() ~= 'worldspawn' or spawn_position:DistToSqr(tr.HitPos) <= 250000 then
							goto skip
						end
					end
				end
			end

			if spawn_position then
				local entities = ents.FindInSphere(spawn_position, 300)

				for _, ent in ipairs(entities) do
					if IsValid(ent) and (ent:IsVehicle() or ent:IsPlayer() or ent:IsNPC()
						or ent:IsNextBot() or ent:GetClass():StartWith('prop_'))
					then
						goto skip
					end
				end

				if point.Neighbors and point.Neighbors[1] then
					local direction_point = dvd.Waypoints[point.Neighbors[1]]

					if direction_point then
						local start_vector_position = spawn_position
						local target_vector_position = direction_point.Target
						spawn_angle = (target_vector_position - start_vector_position):Angle()
					end
				end

				break
			end

			::skip::
			spawn_position = nil
	end

	if not spawn_position or not spawn_angle then return end

	spawn_position = spawn_position + Vector(0, 30, 0)
	spawn_angle = spawn_angle

	return { pos = spawn_position, ang = Angle(0, spawn_angle.y, 0) }
end

bgNPC.FindVehicleSpawnLocation = FindSpawnLocation

function bgNPC:CheckVehicleLimitFromActors(actor_type)
	local limit = GetConVar('bgn_npc_vehicle_max_' .. actor_type):GetInt()
	if limit <= 0 then return false end

	local count = 0

	for i = 1, #bgNPC.DVCars do
		local vehicle_provider = bgNPC.DVCars[i]

		if vehicle_provider.actor_type and vehicle_provider.actor_type == actor_type then
			count = count + 1
		end
	end

	return count < limit
end

function bgNPC:EnterActorInExistVehicle(actor, bypass)
	local actor_data = actor:GetData()
	local chance = actor_data.enter_to_exist_vehicle_chance
	if not bypass and chance and not bgNPC.Util.Chance(chance) then return false end

	local all_players = player.GetAll()
	local block_radius = GetConVar('bgn_spawn_block_radius'):GetFloat() ^ 2

	for i = 1, #bgNPC.DVCars do
		local vehicle_provider = bgNPC.DVCars[i]

		if vehicle_provider:IsValid() and vehicle_provider:IsValidAI() and vehicle_provider:CanUse(actor) then
			local vehicle = vehicle_provider:GetVehicle()
			local driver = vehicle_provider:GetDriver()

			if not driver or not driver:HasTeam(vehicle_provider.type) then
				continue
			end

			-- Поместить в расширение метатаблицы авто библиотеки slib
			local all_seats_are_taken = true

			for _, ent in ipairs(vehicle:GetChildren()) do
				if ent:GetClass() == 'prop_vehicle_prisoner_pod' and not IsValid(ent:GetDriver()) then
					all_seats_are_taken = false
					break
				end
			end

			if all_seats_are_taken then break end
			---  -----------------------------------------------------
			local vehiclePosition = vehicle:GetPos()
			local isVisible = false

			for k = 1, #all_players do
				local ply = all_players[k]
				if not IsValid(ply) then goto skip end

				local distance = vehiclePosition:DistToSqr(ply:GetPos())

				if distance <= block_radius then
					isVisible = true
					break
				end

				if IsValid(ply) and bgNPC.Util.IsInView(ply, vehiclePosition, 70) then
					local tr = util.TraceLine({
						start = ply:EyePos(),
						endpos = vehiclePosition,
						filter = function(ent)
							if IsValid(ent) and ent ~= ply then
								if IsValid(vehicle) then
									if ent ~= vehicle and ent ~= vehicle:GetParent() then
										return false
									end
								else
									return true
								end
							end
						end
					})

					if tr.Hit and (tr.Entity == vehicle or tr.Entity == vehicle:GetParent()) then
						isVisible = true
						break
					end
				end
			end

			if not isVisible then
				actor:EnterVehicle(vehicle)
				return true
			end

			::skip::
		end
	end

	return false
end

function bgNPC:SpawnVehicle(vehicle_class, spawn_pos, spawn_ang, offset_pos, offset_ang)
	local simfphys_list = list.Get('simfphys_vehicles')
	local vehicles_list = list.Get('Vehicles')

	spawn_pos = spawn_pos or Vector(0, 0, 0)
	spawn_ang = spawn_ang or Angle(0, 0, 0)
	offset_pos = offset_pos or Vector(0, 0, 0)
	offset_ang = offset_ang or Angle(0, 0, 0)

	if simfphys and simfphys_list[vehicle_class] then
		local members = simfphys_list[vehicle_class].Members or {}
		local heading = simfphys_forward[vehicle_class]
		if heading == nil and members.CustomWheels and isvector(members.CustomWheelPosFL) and isvector(members.CustomWheelPosFR)
			and isvector(members.CustomWheelPosRL) and isvector(members.CustomWheelPosRR) then
			heading = (members.CustomWheelPosFL + members.CustomWheelPosFR - members.CustomWheelPosRL - members.CustomWheelPosRR):Angle().y
		end
		-- SpawnAngleOffset describes the spawn menu's presentation, not necessarily the physical front.
		local desired = spawn_ang + offset_ang
		local vehicle = simfphys.SpawnVehicleSimple(vehicle_class, spawn_pos + offset_pos, desired - Angle(0, heading or 0, 0))
		if IsValid(vehicle) then
			vehicle.isBgnVehicle = true
			AlignSimfphysSpawn(vehicle, vehicle_class, desired)
		end
		return vehicle
	elseif vehicles_list[vehicle_class] then
		local vehicle_data = vehicles_list[vehicle_class]
		local vehicle = ents.Create(vehicle_data.Class)
		vehicle.isBgnVehicle = true
		vehicle:SetModel(vehicle_data.Model)

		if vehicle_data.KeyValues then
			for k, v in pairs(vehicle_data.KeyValues) do
				vehicle:SetKeyValue(k, v)
			end
		end

		vehicle.VehicleTable = vehicle_data
		vehicle:SetPos(spawn_pos + offset_pos)
		-- vehicle:SetAngles(spawn_ang - vehicle:GetAngles())
		vehicle:SetAngles(spawn_ang + offset_ang)
		vehicle:Spawn()
		vehicle:Activate()
		return vehicle
	end
end

-- @param near Player|nil spawn close to this player (a pursuit) instead of a random one
function bgNPC:SpawnVehicleWithActor(actor, bypass, near)
	if not GetConVar('bgn_enable_dv_support'):GetBool() then return false end
	local dvd = DecentVehicleDestination
	if not dvd or not dvd.Waypoints or #dvd.Waypoints == 0 or player.GetCount() == 0 then return false end

	local actor_data = actor:GetData()
	local car_classes = actor_data.vehicles
	if not car_classes or not istable(car_classes) or #car_classes == 0 then return false end

	local actor_type = actor:GetType()
	if not bypass and not bgNPC:CheckVehicleLimitFromActors(actor_type) then return false end

	local ply = near or bgNPC.Table.Random(player.GetAll())
	local data = FindSpawnLocation(ply:GetPos(), near and bgNPC.PURSUIT_SPAWN_RADIUS)
	if not data then return false end

	local npc = actor:GetNPC()
	local car_class = bgNPC.Table.Random(car_classes)
	local spawn_pos = data.pos + Vector(0, 0, 50)
	if actor_type == 'medic' and bgNPC.Medics and bgNPC.Medics.IsBlocked(spawn_pos) then return false end
	local spawn_ang = data.ang
	local spawn_pos_offest = Vector(0, 0, 0)
	local spawn_ang_offest = Angle(0, 0, 0)

	if actor_data.vehicles_offset_position then
		if istable(actor_data.vehicles_offset_position) then
			local vector =  actor_data.vehicles_offset_position[car_class]
			if vector and isvector(vector) then spawn_pos_offest = vector end
		elseif isvector(actor_data.vehicles_offset_position) then
			spawn_pos_offest = actor_data.vehicles_offset_position
		end
	end

	if actor_data.vehicles_offset_angles then
		if istable(actor_data.vehicles_offset_angles) then
			local angle =  actor_data.vehicles_offset_angles[car_class]
			if angle and isangle(angle) then spawn_ang_offest = angle end
		elseif isangle(actor_data.vehicles_offset_angles) then
			spawn_ang_offest = actor_data.vehicles_offset_angles
		end
	end

	local car = self:SpawnVehicle(car_class, spawn_pos, spawn_ang, spawn_pos_offest, spawn_ang_offest)
	if not IsValid(car) then return false end

	local vehicle_provider = BGN_VEHICLE:Instance(car, actor_data.vehicle_group, actor_type)
	local index = BGN_VEHICLE:AddToList(vehicle_provider)

	if index == -1 then
		car:Remove()
		return false
	end

	if actor_data.vehicles_random_color then
		local vehicles_strict_color_chance = actor_data.vehicles_strict_color_chance or 0
		if not bgNPC.Util.Chance(vehicles_strict_color_chance) then
			car:SetColor(ColorRand())
		else
			local r, g, b = math.random(50, 190), math.random(50, 190), math.random(50, 190)
			car:SetColor(Color(r, g, b))
		end
	end

	if actor_data.vehicles_random_skin then
		local skin_count = car:SkinCount()
		if skin_count ~= 0 then
			car:SetSkin(math.random(1, skin_count))
		end
	end

	if actor_data.vehicles_random_bodygroups then
		local bodygroups = car:GetBodyGroups()
		for i = 1, #bodygroups do
			local bodygroup = bodygroups[i]
			local values_count = car:GetBodygroupCount(bodygroup.id)
			local new_value = math.random(0, values_count)
			car:SetBodygroup(bodygroup.id, new_value)
		end
	end

	local original_color = car:GetColor()
	car:SetColor(ColorAlpha(original_color, 0))

	bgNPC.Util.EntityTimer(car, 'spawn_dv_ai', .1, 1, function(ent)
		if not IsValid(npc) then
			ent:Remove()
			return
		end

		car:SetColor(ColorAlpha(original_color, 255))
		npc:SetPos(ent:GetPos())
		actor:EnterVehicle(ent)
	end)

	return true
end
