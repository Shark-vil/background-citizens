local function spawn_npc(npc_class, models, spawn_position, spawn_angle)
	local npc = ents.Create(npc_class)
	if not IsValid(npc) then return end

	npc:SetPos(spawn_position)
	npc:SetAngles(spawn_angle)
	npc:Spawn()

	if models then
		if istable(models) then
			for _, v in ipairs(models) do
				npc:SetModel(v)
			end
		elseif isstring(models) then
			npc:SetModel(models)
		end
	end

	npc:Activate()
	npc:Remove()
end

local function spawn_vehicle(vehicle_class, spawn_position, spawn_angle)
	local vehicle = bgNPC:SpawnVehicle(car_class, spawn_position, spawn_angle)
	if not IsValid(vehicle) then return end
	vehicle:Remove()
end

hook.Add('PlayerSpawn', 'BGN_PreSpawnEntities_CacheService',  function()
	hook.Remove('PlayerSpawn', 'BGN_PreSpawnEntities_CacheService')

	local spawn_position = Vector(0, 0, 0)
	local spawn_angle = Angle(0, 0, 0)

	for k, v in pairs(bgNPC.cfg.npcs_template) do
		if v.class then
			if istable(v.class) then
				for _, npc_class in ipairs(v.class) do
					spawn_npc(npc_class, v.models, spawn_position, spawn_angle)
				end
			elseif isstring(v.class) then
				spawn_npc(v.class, v.models, spawn_position, spawn_angle)
			end
		end

		if v.vehicles then
			if istable(v.vehicles) then
				for _, vehicle_class in ipairs(v.vehicles) do
					spawn_vehicle(vehicle_class, spawn_position, spawn_angle)
				end
			elseif isstring(v.vehicles) then
				spawn_vehicle(v.vehicles, spawn_position, spawn_angle)
			end
		end
	end
end)